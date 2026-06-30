
---

**1) 模块/分层图（组件视角）**

```mermaid
flowchart TB
  subgraph UI["UI / 调用入口（ViewController）"]
    Runner["ExperimentRunner\n(编排 Case1/2/3)"]
  end

  subgraph Env["ExperimentEnvironment（可重置容器）"]
    Metrics["Metrics\n(hit/miss/origin/timeout/p95...)"]
    Cache["TTLCacheStore\n(TTL 缓存)"]
    SF["SingleFlight\n(并发合并)"]
    Fetcher["CachedFetcher\n(缓存策略 + singleflight 开关)"]
    Client["NetworkClient\n(interceptor chain)"]
    Err["ErrorInjector\n(按概率 5xx)"]
    Timeout["TimeoutInjector\n(注入延迟 + 超时判定)"]
    Origin["LocalOriginTransport\n(本地源站响应)"]
  end

  Runner --> Env
  Env --> Fetcher
  Fetcher --> Cache
  Fetcher --> SF
  Fetcher --> Client
  Client --> Err --> Timeout --> Origin

  Metrics -. 统计 .- Fetcher
  Metrics -. 统计 .- Timeout
  Metrics -. 统计 .- Err
  Metrics -. 统计 .- Origin
```

核心含义：
- `CachedFetcher` 决定“走缓存”还是“回源”，以及回源是否使用 `SingleFlight` 合并并发。
- `NetworkClient` 是拦截器链（B 方案）：`ErrorInjector -> TimeoutInjector -> LocalOriginTransport`。
- `LocalOriginTransport` 不出网，本地生成 JSON，同时用来统计 origin fetch 次数（击穿/合并最直观的指标）。

---

**2) 一次 fetch 的主流程图（命中 vs 未命中）**

```mermaid
flowchart TD
  A["fetch(url)"] --> B{"TTLCacheStore.get(key)\n是否命中且未过期?"}
  B -- "命中" --> H["Metrics.cacheHit++\n记录 latency\n返回 cached Data"]
  B -- "未命中/已过期" --> M["Metrics.cacheMiss++"]
  M --> S{"enableSingleFlight?"}
  S -- "OFF" --> O1["直接回源 1 次（每个并发都这么做）"]
  S -- "ON" --> O2["SingleFlight.do(key)\n同 key 只允许 1 次回源\n其余等待复用结果"]
  O1 --> N["NetworkClient(interceptors)->Transport"]
  O2 --> N
  N --> R{"结果成功?"}
  R -- "成功(非5xx/非超时)" --> W["写入 TTL 缓存 (set ttl)\n记录 latency\n返回成功"]
  R -- "失败/超时/5xx" --> F["不写缓存\n记录 latency\n返回失败"]
```

关键点对应你的“严格定义”：
- 失败/超时/5xx 不写缓存（无 negative cache）。
- `expire(key)` 删除缓存条目，保证实验能稳定复现“瞬间 N 并发 + TTL 已过期”的场景。

---

**3) 拦截器链（B 方案）如何“模拟网络”**

```mermaid
sequenceDiagram
  participant Fetcher as CachedFetcher
  participant Client as NetworkClient
  participant Err as ErrorInjector
  participant T as TimeoutInjector
  participant Origin as LocalOriginTransport

  Fetcher->>Client: data(for: request)
  Client->>Err: intercept
  alt 命中 5xx 概率
    Err-->>Fetcher: 直接返回 503 + body
  else 未触发 5xx
    Err->>T: next(request)
    T->>Origin: next(request)
    Origin-->>T: 200 + JSON（originFetch++）
    alt 注入延迟 > timeoutThreshold
      T-->>Fetcher: 在 threshold 时刻返回 URLError.timedOut（timeout++）
    else 注入延迟 <= threshold
      T-->>Fetcher: 延迟 injectedDelay 后返回原结果
    end
  end
```

对应代码语义：
- `ErrorInjector` 可短路直接返回 503（不走 “源站”）。
- `TimeoutInjector` 做“延迟注入 + 超时判定”：当 `injectedDelayMs > timeoutThresholdMs` 时返回 `URLError(.timedOut)` 并计数。

---

**4) 缓存击穿 vs SingleFlight 合并（最关键对照）**

同一 key，TTL 已过期的一瞬间，同时来了 N 个并发请求：

**singleflight = OFF（击穿）**
```mermaid
sequenceDiagram
  participant C1 as Req1
  participant C2 as Req2
  participant C3 as Req3
  participant Cache as TTLCacheStore
  participant Origin as LocalOriginTransport

  C1->>Cache: get(key)=miss
  C2->>Cache: get(key)=miss
  C3->>Cache: get(key)=miss
  par 并发回源
    C1->>Origin: execute (originFetch++)
    C2->>Origin: execute (originFetch++)
    C3->>Origin: execute (originFetch++)
  end
```
结果：`originFetch ≈ N`

**singleflight = ON（合并）**
```mermaid
sequenceDiagram
  participant C1 as Req1
  participant C2 as Req2
  participant C3 as Req3
  participant SF as SingleFlight
  participant Origin as LocalOriginTransport

  C1->>SF: do(key) 作为 leader
  C2->>SF: do(key) 加入 waiters
  C3->>SF: do(key) 加入 waiters
  C1->>Origin: execute (originFetch++)
  Origin-->>SF: result
  SF-->>C1: result
  SF-->>C2: result (复用)
  SF-->>C3: result (复用)
```
结果：`originFetch ≈ 1`

---

**5) TTL 的“时间线图”（为什么需要 expire 才稳定复现）**

```text
t0            t0+TTL                 t0+TTL+ε
|---- 有效期 ----|----------------------|
写入缓存        过期（读到会删）        触发 N 并发（击穿/合并的实验点）
```

- 没有 `expire(key)` 时，你很难保证每次点击按钮时刚好落在 “过期后瞬间”。
- 用 `expire(key)` 等价于人为把时间线直接跳到 “过期之后”，确保 N 并发一定 miss，从而稳定观察 origin 次数差异。

---