# SingleFlightDemo 核心技术要点

## 目标
用最小可运行 Demo 说明 SingleFlight 在客户端的价值：
- 合并同 key 并发回源，减少回源次数（origin）
- 让等待者共享同一个结果，降低 401 风暴/缓存击穿/IO 放大
- 可观测：能量化合并收益与等待开销（coalesced、wait P95/P99、inflight 峰值）

入口代码：ViewController.swift

## SingleFlight 的语义与实现
- 同一 key 在 inflight 期间：
  - 首个请求触发 start（真正回源）
  - 后续并发只 join，挂起等待，不再回源
- 回源完成：
  - 原子 remove inflight[key]
  - 对所有等待者回调同一个 Result

实现要点：
- NSLock 保护 inflight 字典
- inflight[key] 保存 startedAt + callbacks 队列
- 不负责线程切换：回调执行队列由 start 决定

## 可观测信号（DemoMetrics）
事件划分：
- onStart：每个 key 的“真实回源”次数；记录 inflight 字典大小用于估算并发深度峰值
- onJoin：合并次数（有等待者加入）
- onFinish：等待时延（ms）与成功失败

指标含义（ViewController header）：
- origin：真实回源次数（singleflight 开启后应显著降低）
- coalesced：合并次数（并发越多越高）
- inflightMax：inflight 字典峰值（同时存在多少个不同 key 的回源）
- waitP95 / waitP99：等待时延分位（合并带来的排队等待成本）
- ok / fail：回源成功失败计数

注意：当前实现为 demo 简化，onFinish 只用于统计，不保留真实 payload。

## Singleflight Key 设计（SFKey）
原则：
- key 必须包含“会影响结果的维度”
- key 必须稳定：避免把随机/时间戳/未归一化 query 顺序带进 key
- 粒度要适中：过粗会串数据，过细会失去合并率

本 Demo 覆盖 7 类必用场景 key 组成：
1) Token 刷新：refresh:{userId}:{authScope}:{env}
2) 用户信息：me:{userId}:{authScope}:{locale}:{appVersion}
3) 配置中心：config:{userOrAnon}:{deviceId}:{locale}:{region}:{appVersion}:{scene}:{env}
4) 热点详情：item:{resourceId}:{userOrAnon}:{locale}:{region}:{fieldsMask}
5) 媒体元数据：mediaMeta:{mediaId}:{variant}:{userOrAnon}:{authScope}:{locale}
6) 缓存击穿回源：cacheFill:{logicalKey}:{userOrAnon}:{locale}:{region}:{appVersion}
7) DB/磁盘读：dbRead:{table}:{primaryKey}:{projection}

## 7 个场景如何触发
ViewController 提供 7 个按钮，每次触发 burst x8 并发：
- SingleFlight=ON：同场景一次 burst，origin 约 +1，coalesced 约 +7
- SingleFlight=OFF：同场景一次 burst，origin 约 +8，coalesced 不增长

其中“缓存击穿回源”会先 expire logicalKey，再并发触发 getOrLoadCache。

## 生产化边界（待扩展）
- 必须保证 start 最终回调一次，否则 inflight 泄漏（可加超时/兜底清理）
- 副作用请求不应合并（或需强幂等保障），如某些写接口
- 失败传播策略要显式：失败是否广播给全部等待者、是否允许 stale-while-revalidate
- 可加：每 key 最大等待者数、全局并发上限、按错误类型打点（401/timeout 等）