# SysArchDesignDemo2 — 解耦架构重构 Demo

## 项目概述

SysArchDesignDemo1 的 **协议解耦重构版**。将原本内嵌在控制器中的缓存、网络、拦截器、SingleFlight 逻辑全部抽离为 **协议驱动的独立组件**（`Transport` / `AsyncInterceptor` / `TTLCache` / `SingleFlight`），通过 `DemoEnv` 组合编排，实现了 **高内聚低耦合** 的架构目标。

保留完整实验场景：预热缓存 → 过期缓存 → 单次回源 → 8x 并发击穿，支持超时注入开关 + SingleFlight 开关的交叉组合。

## 项目结构

```
SysArchDesignDemo2/
├── SysArchDesignDemo2/
│   └── ViewController.swift   # 全部逻辑（~368 行）：协议层 + 组件层 + 编排层 + UI 层
├── SysArchDesignDemo2.xcodeproj
└── README.md
```

**单文件架构**（对比 SysArchDesignDemo1 的 ~650 行缩至 ~368 行），核心重构在于引入协议抽象。

---

## 技术要点

### 一、解耦架构分层

```
┌─────────────────────────────────────────────────┐
│  ViewController（UI 层）                          │
│    仅负责：按钮事件 → env.fetch() → 渲染指标        │
│    不包含任何缓存/网络/并发逻辑                      │
├─────────────────────────────────────────────────┤
│  DemoEnv（编排层）                                 │
│    组合 cache + singleFlight + client            │
│    fetch() 流程：Cache 命中? → 直接返回            │
│                  Cache miss? → SingleFlight? → Client   │
├──────────────┬──────────────────────────────────┤
│  TTLCache    │  SingleFlight      │  NetworkClient │
│  (存储层)     │  (并发层)           │  (网络层)       │
│  NSLock+Map  │  NSLock+inflight   │  Transport +    │
│  惰性过期     │  回调广播           │  Interceptor[]  │
├──────────────┴────────────────────┼────────────────┤
│                                   │  Transport     │
│                                   │  (协议)         │
│                                   │  FakeTransport │
│                                   └────────────────┤
│                                   ┌────────────────┤
│                                   │AsyncInterceptor│
│                                   │ (协议)          │
│                                   │TimeoutInjector │
│                                   └────────────────┤
└─────────────────────────────────────────────────┘
```

### 二、协议定义

#### Transport 协议

```swift
protocol Transport {
    func send(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void)
}
```

- 抽象网络层：上层不感知底层是 HTTP/DNS/gRPC 还是 Mock
- `FakeTransport` 以 `URLRequest` 为输入，返回 `Result<Data, Error>` 为输出
- 可无缝替换为 `URLSession.shared.dataTask` 等真实实现

#### AsyncInterceptor 协议

```swift
protocol AsyncInterceptor {
    func intercept(
        _ request: URLRequest,
        next: @escaping (URLRequest, @escaping (Result<Data, Error>) -> Void) -> Void,
        completion: @escaping (Result<Data, Error>) -> Void
    )
}
```

- `next` 闭包传递链式调用上下文（`request` + 下游回调）
- `completion` 是当前拦截器的终局回调
- 与 `Interceptor`（同步）不同，支持异步拦截（超时注入、重试、链路追踪等）

#### 拦截器链执行模型

```swift
// NetworkClient.send → sender(0, request, completion)
func sender(_ index: Int, _ req: URLRequest, _ done: @escaping (Result<Data, Error>) -> Void) {
    if index >= interceptors.count {
        transport.send(req, completion: done)  // 链尾：真正发送
        return
    }
    interceptors[index].intercept(req, next: { r, cb in
        sender(index + 1, r, cb)  // 传递到下一个拦截器
    }, completion: done)
}
```

### 三、TTLCache（与 SysArchDesignDemo1 一致）

```swift
final class TTLCache {
    private let lock = NSLock()
    private var map: [String: (Data, Date)] = [:]
    // get(): 惰性过期 — 读取时发现过期则 removeValue 并返回 nil
    // set(key, data, ttl)
    // expire(key): 直接 removeValue
    // hasValid(key): 同 get 逻辑但不返回 data
}
```

### 四、SingleFlight（带详细代码注释）

```swift
final class SingleFlight {
    func run(key: String,
             start: (@escaping (Result<Data, Error>) -> Void) -> Void,
             completion: @escaping (Result<Data, Error>) -> Void)
}
```

与 SingleFlightDemo 一致的核心实现，代码中包含 **逐行中文注释** 解释：
- `inflight[key]` 的含义（已有回源在进行 vs 首次回源）
- 为什么需要加锁（共享可变状态多线程读写）
- 首个请求 vs join 请求的分支逻辑
- `weak self` 的使用原因（避免循环引用 + 防止 self 释放后等待者收不到回调）
- 原子 `removeValue` 的必要性

### 五、TimeoutInjector

```swift
final class TimeoutInjector: AsyncInterceptor {
    var enabled = false
    var timeoutSeconds: TimeInterval = 1.2

    func intercept(..., next: ..., completion: ...) {
        if enabled && seq % 3 == 0 {  // 每第 3 个请求注入超时
            DispatchQueue.global().asyncAfter(timeoutSeconds) {
                completion(.failure(URLError(.timedOut)))
            }
            return                         // 不调用 next，直接短路返回
        }
        next(request, completion)          // 未命中注入：正常传递
    }
}
```

- 基于序列号 `seq` 的确定性注入（每第 3 次请求），可复现
- 短路 `next` 调用，不消耗下游资源
- `throw` vs `completion(.failure(...))`：异步拦截器必须走回调模式

### 六、DemoEnv 编排层

```swift
func fetch(key: String, ttl: TimeInterval, completion: ...) {
    // 1. 缓存命中 → 直接返回 + hit++
    if let data = cache.get(key) {
        metrics.hit += 1
        completion(.success(...))
        return
    }
    metrics.miss += 1

    // 2. 缓存未命中 → 准备回源
    let req = URLRequest(...)
    let start = { done in
        self.metrics.origin += 1
        self.client.send(req, completion: done)  // 走 NetworkClient（拦截器链）
    }
    let finish = { result in
        // 3. 回源成功 → 写缓存 + 返回
        // 4. 回源失败 → 识别 timeout + 透传错误
    }

    // 5. SingleFlight 开关
    if enableSingleFlight {
        singleFlight.run(key: key, start: start, completion: finish)
    } else {
        start(finish)
    }
}
```

**流程分叉：**
1. Cache hit → 直接返回，`origin=0`
2. Cache miss + SingleFlight ON → `singleFlight.run`（并发合并）
3. Cache miss + SingleFlight OFF → 每个请求独立 `start`

### 七、指标体系

```swift
struct DemoMetrics {
    var hit = 0      // 缓存命中
    var miss = 0     // 缓存未命中
    var origin = 0   // 真实回源次数
    var timeout = 0  // 超时次数
}
```

统计头展示：

```
key=item_42 ttl=4s burst=8 singleflight=true
hit=0 miss=8 origin=1 timeout=0 cache=valid
```

### 八、实验配置

| 操作 | 按钮 | 效果 |
|------|------|------|
| 预热缓存 | Warm Cache | `cache.set(key, ttl:4s)` |
| 过期缓存 | Expire Cache | `cache.expire(key)` → 模拟击穿 |
| 单次回源 | Fetch Once | 1 次请求 |
| 8x 并发 | Burst x8 | `burst=8` 并发，观察 origin/coalesced |

**Toggle 开关：**
- 超时注入：`TimeoutInjector.enabled` — 每第 3 个请求返回 timeout
- SingleFlight：`enableSingleFlight` — ON/OFF 对比 origin 数量

---

## 与 SysArchDesignDemo1 的对比

| 维度 | SysArchDesignDemo1 | SysArchDesignDemo2（本 Demo） |
|------|-------------------|-------------------------------|
| 架构风格 | 拦截器链 + 实验系统，单体实现 | **协议解耦**，组件独立可替换 |
| 代码量 | ~650 行 | ~368 行 |
| 拦截器 | 5 个内嵌拦截器类 | 1 个 `AsyncInterceptor` 协议 + 1 个实现 |
| 网络层 | 直接 `URLSession` | `Transport` 协议 + `FakeTransport` |
| 指标 | 完整：P95/p50/min/max/命中率 | 精简：hit/miss/origin/timeout |
| 实验设计 | 3 个 Cases 自动执行 | 手动按钮控制 |
| 扩展性 | 修改拦截器需改 NetworkClient | 新增拦截器只需实现 `AsyncInterceptor` |
| 组装方式 | 构造函数注入 | `DemoEnv` 组合编排 |
| 文档 | Network.md + qa.md + Mermaid 图 | 代码注释 + README |
| 定位 | **面试评审完整方案** | **重构教学 + 协议驱动机性** |

---

## 运行方式

```bash
cd SysArchDesignDemo2
open SysArchDesignDemo2.xcodeproj
# Xcode 中选择模拟器 → Run
```

**实验步骤：**
1. Warm Cache → Fetch Once → 观察 `hit=1, origin=0`
2. 开启 SingleFlight → Expire Cache → Burst x8 → 观察 `origin=1`（合并成功）
3. 关闭 SingleFlight → Burst x8 → 观察 `origin=8`（各回各的）
4. 开启超时注入 → Burst x8 → 观察 `timeout=N`

## 技术标签

`iOS` `架构设计` `协议驱动` `依赖注入` `拦截器链` `AsyncInterceptor` `SingleFlight` `TTLCache` `Transport` `解耦重构` `NetworkClient` `TimeoutInjector` `NSLock`
