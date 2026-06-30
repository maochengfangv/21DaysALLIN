**面试梳理（5 张问题卡片）**

**卡片 1：你这个 Demo 解决了什么问题？为什么选 interceptor chain（B 方案）？**
- 问题：请用 30 秒介绍这个 Demo 的目标与整体架构。
- 30 秒回答：这是一个可重复复现实验的网络/缓存小基建切片：用 `TTLCacheStore` 控制命中与过期，用 `SingleFlight` 对照复现缓存击穿（singleflight=off 时 origin≈N，on 时 origin≈1），并通过 `NetworkClient` 的 interceptor chain 注入可控延迟/超时/5xx，同时用 `Metrics` 输出 hit/miss、origin、timeout、p95 延迟等指标，方便定位性能与稳定性问题。选 B 方案（wrapper + chain）是因为范围可控、不污染全局网络栈，便于在一个 environment 内 reset/更新参数并稳定复现。
- 追问点：
  - 为什么不用 `URLProtocol`（全局拦截）？它的注册范围、缓存、与系统行为的坑有哪些？
  - interceptor chain 的好处是什么（可组合、可测试、可控实验变量）？
  - 这个 demo 如何做到“不依赖真实网络”？
- 代码定位：
  - [NetworkClient](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L232-L260)
  - [LocalOriginTransport](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L329-L349)
  - [ExperimentEnvironment](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L423-L518)

**卡片 2：TTL 是什么？你这里的缓存策略/过期策略如何定义？**
- 问题：TTL 缓存的正确性怎么保证？什么时候写缓存、什么时候删缓存？
- 30 秒回答：TTL（Time To Live）是缓存条目的有效期。这里 `TTLCacheStore.get` 在读时检查 expiry，过期立即移除并返回 nil，避免返回陈旧数据；`CachedFetcher` 的策略是先读缓存，命中直接返回并计 `cacheHit`；未命中才回源并计 `cacheMiss`；回源成功才写缓存（失败/超时/5xx 不写，避免把错误缓存住）。为了稳定复现击穿/合并对照，提供 `expire(key)` 强制过期。
- 追问点：
  - 读时删除 vs 后台定时清理，各自优缺点？
  - 为什么失败/超时不写缓存？什么时候你会引入 negative cache？
  - key 设计：为什么用 `url.absoluteString`，生产里如何做 URL 归一化？
- 代码定位：
  - [TTLCacheStore](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L150-L192)
  - [CachedFetcher（命中/未命中与写入规则）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L351-L420)
  - [ExperimentEnvironment.expire](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L507-L517)

**卡片 3：缓存击穿怎么复现？singleflight 为什么能把 origin 从 N 降到 1？**
- 问题：解释 singleflight 的实现与并发语义。
- 30 秒回答：击穿发生在同 key 过期瞬间的 N 并发 miss：singleflight=off 时每个请求都直接回源，因此 `originFetch≈N`。singleflight=on 时，`SingleFlight` 维护 per-key 的 inflight 队列：第一个请求成为 leader 发起 work，后续并发加入 waiters；leader 完成后把同一个结果 fan-out 给所有 waiters，因此回源只发生一次，`originFetch≈1`。这个 demo 用 originFetch 计数来直观验证合并是否生效。
- 追问点：
  - leader 卡住/永不回调怎么办（超时、取消、释放 waiters）？
  - waiters 队列会不会爆（上限、丢弃、降级）？
  - singleflight 对 p95 延迟的影响（可能降低回源压力，但会引入等待复用）？
- 代码定位：
  - [SingleFlight.do](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L194-L230)
  - [CachedFetcher（singleflight 分支）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L385-L419)
  - [LocalOriginTransport（originFetch 口径）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L338-L349)

**卡片 4：超时/错误是如何“严格定义并可复现”的？与 URLSession timeout 有什么区别？**
- 问题：你怎么实现“注入延迟导致超时”的严格定义？
- 30 秒回答：这里的超时不是依赖系统网络栈的 timeoutInterval，而是实验定义：`TimeoutInjector` 生成 injectedDelayMs（base+jitter 或按概率强制超过阈值），若 `injectedDelayMs > timeoutThresholdMs`，就在阈值时刻返回 `URLError(.timedOut)` 并计 `metrics.timeout`；否则延迟 injectedDelayMs 后再返回原结果。错误注入由 `ErrorInjector` 按概率短路返回 503，用于模拟 5xx。
- 追问点：
  - 生产中如何做真正的超时（取消底层任务、避免重复回调）？
  - 注入器链路顺序是否重要（先 error 后 timeout vs 反过来）？
  - 概率注入如何做可重复（固定随机种子）？
- 代码定位：
  - [TimeoutInjector（超时定义）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L262-L304)
  - [ErrorInjector（5xx 注入）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L306-L327)

**卡片 5：你怎么做“可观测性”和“线程安全”？指标口径是什么？**
- 问题：你输出了哪些指标，怎么保证线程安全？
- 30 秒回答：`Metrics` 记录 cache hit/miss、originFetch、timeout、5xx、以及每次 fetch 的 latency（用于 avg/p95）。这些计数与数组在多线程下会并发读写，因此用 `NSLock` 保护临界区，保证口径一致。击穿/合并是否生效用 originFetch 最直观；尾延迟用 p95 观察 singleflight 与超时注入的影响。
- 追问点：
  - `NSLock` 与自旋锁/`os_unfair_lock` 的差异与取舍？
  - p95 计算的样本量问题（N 小时抖动，如何做更稳定的统计）？
  - 如果升级生产级：cancel/timeout 联动、negative cache、限流熔断、分层缓存、key 归一化、埋点落地等。
- 代码定位：
  - [Metrics](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L40-L148)
  - [ExperimentRunner（输出格式/总耗时）](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/SysArchDesignDemo1/SysArchDesignDemo1/NetworkExperiment.swift#L520-L650)