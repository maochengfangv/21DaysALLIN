# SingleFlightDemo — 并发请求合并（SingleFlight）可观测 Demo

## 项目概述

一个 **独立封装的 SingleFlight 引擎** 的可运行 Demo，覆盖 **7 类生产级必用场景**（Token 刷新/用户信息/配置中心/热点详情/媒体元数据/缓存击穿回源/DB 读），每个场景支持 **8x 并发突发测试**，对比 SingleFlight ON/OFF 的 origin/coalesced 差异。附带 **TTL 缓存 + SWR（Stale-While-Revalidate）**、**完整可观测指标体系**（origin/coalesced/stale/bypass/reject/timeout/inflightMax/waitP95/waitP99/ok/fail）、**生产级边界安全策略**（超时兜底/maxWaiters/失败传播/canonicalQuery）。

## 项目结构

```
SingleFlightDemo/
├── SingleFlightDemo/
│   ├── ViewController.swift    # UI + 7 场景触发 + 指标渲染（~145 行）
│   ├── SceneDelegate.swift
│   ├── AppDelegate.swift
│   └── ReadMe.md               # 核心技术要点说明（key 设计清单 + 生产化边界）
└── README.md
```

**单文件架构**：[ViewController.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SingleFlightDemo/SingleFlightDemo/ViewController.swift)（~588 行）包含 **全部实现**：SingleFlight 引擎、TTLCache、DemoMetrics、SFKey、7 场景 Repository、FakeBackend、SingleFlightPolicy、Observer 体系。

---

## 技术要点

### 一、SingleFlight 引擎核心实现

```swift
final class SingleFlight<Value> {
    private let lock = NSLock()
    private var inflight: [String: Entry] = [:]

    struct Entry {
        let startedAt: CFAbsoluteTime        // 统计等待时延（wait P95/P99）
        let start: (...) -> Void              // 真实回源闭包
        let policy: SingleFlightPolicy        // 合并/超时/失败传播策略
        var callbacks: [(Result<Value,Error>) -> Void]  // 等待队列
        var timeoutWorkItem: DispatchWorkItem? // 超时兜底
    }
}
```

**执行流程：**

```
run(key, policy, start, completion)
  │
  ├── effect == .nonMergeableSideEffect?
  │     └── bypass: 直接执行 start，不合并
  │
  ├── inflight[key] 已存在?
  │     ├── callbacks.count >= maxWaiters?
  │     │     └── reject: .tooManyWaiters
  │     └── join: callbacks.append(completion) + onJoin
  │
  └── 首个请求
        ├── 创建 Entry + 入 inflight → onStart
        ├── installTimeoutIfNeeded (DispatchWorkItem)
        └── start { result → finish() }
              ├── atomic remove inflight[key]
              ├── timeoutWorkItem?.cancel()
              ├── waitMs = CFAbsoluteTimeGetCurrent() - startedAt
              ├── 失败传播策略判定 (broadcast / retryIndividually)
              └── callbacks.forEach { $0(result) } → onFinish
```

**核心约束：**
- **不持锁回源**：创建 Entry 后立即 `unlock`，再执行 `start`，避免阻塞 join 请求
- **原子 remove**：`finish` 中原子移除 `inflight[key]`，防止竞态
- **回调队列由 start 决定**：SingleFlight 不负责线程切换

### 二、SingleFlightPolicy（生产边界策略）

```swift
struct SingleFlightPolicy {
    let effect: RequestEffect            // 请求语义分类
    let timeoutMs: Int                   // 超时兜底（0 = 不限）
    let maxWaiters: Int                  // 每 key 最大等待者（防止热点膨胀）
    let failureStrategy: FailureStrategy // 失败传播策略
    let staleWhileRevalidate: Bool       // SWR 开关
}
```

#### RequestEffect

| 值 | 语义 | 行为 |
|----|------|------|
| `.readOnly` | 纯读请求 | 正常合并 |
| `.idempotentSideEffect` | 幂等副作用（如 Token 刷新） | 可合并 |
| `.nonMergeableSideEffect` | 不可合并副作用（写接口/扣费） | 直接 bypass，不合并 |

#### FailureStrategy

| 值 | 行为 | 适用场景 |
|----|------|----------|
| `.broadcastSharedFailure` | 所有等待者共享同一个失败 | Token 刷新/配置中心（统一收敛） |
| `.retryJoinersIndividually` | 首个请求收到失败，其余 joiner 各自重试 | 热点详情/DB 读（避免单次错误放大） |

#### 7 场景策略对照

| 场景 | effect | timeoutMs | maxWaiters | failureStrategy | SWR |
|------|--------|-----------|------------|-----------------|-----|
| Token 刷新 | `.idempotentSideEffect` | 1500 | 12 | `.broadcastSharedFailure` | ✗ |
| 用户信息 | `.readOnly` | 1200 | 24 | `.broadcastSharedFailure` | ✗ |
| 配置中心 | `.readOnly` | 1200 | 24 | `.broadcastSharedFailure` | ✓ |
| 热点详情 | `.readOnly` | 1200 | 48 | `.retryJoinersIndividually` | ✗ |
| 媒体元数据 | `.readOnly` | 1000 | 48 | `.broadcastSharedFailure` | ✗ |
| 缓存击穿回源 | `.readOnly` | 1200 | 48 | `.broadcastSharedFailure` | ✓ |
| DB/磁盘读 | `.readOnly` | 900 | 16 | `.retryJoinersIndividually` | ✗ |

### 三、TTL 缓存 + SWR（Stale-While-Revalidate）

```swift
final class TTLCache {
    func getFresh(_ key: String) -> String?   // TTL 未过期
    func getStale(_ key: String) -> String?   // 即使过期也返回（SWR 用）
    func set(_ key: String, value: String, ttlSeconds: TimeInterval)
    func expire(_ key: String, keepStale: Bool = true)  // keepStale: 过期但保留值
}

// SWR 分支逻辑
func serveFreshOrStale(cacheKey, key, policy, start, completion) {
    if let fresh = cache.getFresh(cacheKey)
        → completion(.success("fresh ..."))            // 命中：直接返回
    if policy.staleWhileRevalidate, let stale = cache.getStale(cacheKey)
        → completion(.success("stale ..."))            // 先返回 stale
        → revalidate(key, policy, start)               // 后台异步刷新
    else
        → run(key, policy, start, completion)          // 未命中：正常回源
}
```

- `TTLCache` 使用 `NSLock` 保护内部 `[String: (value, expireAt)]` 字典
- `expire(keepStale: true)` 将 `expireAt` 设为 `.distantPast` 但保留 value，用于模拟缓存过期+击穿
- `revalidate` 使用 fire-and-forget 模式，忽略后台刷新结果

### 四、Key 设计体系（SFKey）

详见 [ReadMe.md](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SingleFlightDemo/SingleFlightDemo/ReadMe.md) 的完整清单。

**设计原则：**
- key 必须包含所有影响结果的维度（userId/scope/locale/region/appVersion 等）
- 必须稳定：不能包含时间戳、随机值、未归一化的 query 顺序
- 粒度适中：过粗会串数据，过细会失去合并率

**canonicalQuery — query 参数稳定化：**

```swift
private func canonicalQuery(_ query: [String: String]) -> String {
    query.keys.sorted().map { "\($0)=\(query[$0] ?? "")" }.joined(separator: "&")
    // 确保 {b:2,a:1} 和 {a:1,b:2} 生成相同的 "a=1&b=2"
}
```

### 五、可观测性（DemoMetrics）

```
观察者协议
SingleFlightObserver:
  onStart(key, inflight)     → origin += 1, inflightMax = max(inflightMax, inflight)
  onJoin(key)                → coalesced += 1
  onFinish(key, waiters, waitMs, result) → ok/fail += 1, waitSamplesMs.append(waitMs)
  onStale(key)               → stale += 1
  onBypass(key, reason)      → bypass += 1
  onRejectJoin(key, max)     → rejected += 1
  onTimeout(key)             → timeout += 1
```

**指标头展示：**

```
sf=true origin=1 coalesced=7 stale=0 bypass=0 reject=0 timeout=0
inflightMax=1 ok=8 fail=0 waitP95=0ms waitP99=0ms
```

**生产化扩展方向（已预留）：**
- 按错误类型分类打点（401/timeout/5xx 等）
- 全局并发上限（非 per-key）
- 与 APM 系统集成（Datadog/Prometheus 等）

### 六、8x 突发测试

```swift
// ViewController 中 7 个按钮各触发 burst(tag:count:8)
burst(tag: "refresh", count: 8) { done in
    repo.refreshToken(userId: "u1", authScope: "default", completion: done)
}
```

| SingleFlight | origin | coalesced | 缓存回源次数 |
|-------------|--------|-----------|-------------|
| ON | ~1 (只回源 1 次) | ~7 (7 个 joiner 合并) | 1 次 |
| OFF | ~8 (各回各的) | ~0 | 8 次 |

缓存击穿回源场景额外执行 `repo.expireCache(logicalKey: "feed_home")` 模拟缓存过期。

### 七、生产边界安全

| 机制 | 实现 | 作用 |
|------|------|------|
| **超时兜底** | `DispatchWorkItem` + `asyncAfter(timeoutMs)` | 防止 start 永不回调导致 inflight 泄漏 |
| **maxWaiters** | 达到上限拒绝新 joiner | 防止热点 key 回调队列无限膨胀 |
| **nonMergeableSideEffect** | bypass 直接执行，不合并 | 防止写接口/扣费被合并破坏语义 |
| **canonicalQuery** | query key 排序稳定化 | 防止同语义不同顺序产生不同 key |
| **SWR 后台刷新** | fire-and-forget revalidate | 先返回 stale，再后台更新，不阻塞用户 |

---

## 运行方式

```bash
cd SingleFlightDemo
open SingleFlightDemo.xcodeproj
# Xcode 中选择模拟器 → Run
```

1. 默认 SingleFlight **ON** → 点击任意场景按钮 → 观察 `origin=1, coalesced=7`
2. 关闭 SingleFlight Switch → 再次点击 → 观察 `origin=8, coalesced=0`
3. 缓存击穿回源场景：先 expire 缓存 → 并发触发 → 观察 first round `origin=1` 之后 fresh 命中 `origin=0`

## 与 SysArchDesignDemo1 的关系

本 Demo 的 SingleFlight 引擎是 SysArchDesignDemo1 中 `NetworkExperiment.SingleFlight` 的 **独立可复用版本**，去除了网络层耦合，增加了 SWR、FailureStrategy、Observer 体系、canonicalQuery 等生产化扩展。

## 技术标签

`iOS` `SingleFlight` `并发控制` `缓存击穿` `SWR` `Stale-While-Revalidate` `Token 刷新` `TTL 缓存` `maxWaiters` `failureStrategy` `canonicalQuery` `可观测性` `P95/P99` `NSLock` `DispatchWorkItem`
