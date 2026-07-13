# Feed 曝光（Exposure）实现梳理

本文梳理本项目 Feed 流页面的“曝光确认 + 去重 + 曝光后按需拉详情（lazy request）”实现，重点解释：为什么用 ref 状态机而不是全用 React state，以及如何把 UI 更新控制在最小范围。

相关文件：
- 页面：src/pages/basics/FlatListScreen.tsx
- Item：src/pages/basics/feed/FeedItem.tsx
- Mock：src/pages/basics/feed/mockFeed.ts
- 埋点：src/services/analytics.ts

## 口径与参数

- 可见阈值：EXPOSURE_VISIBLE_THRESHOLD（FlatList viewabilityConfig.itemVisiblePercentThreshold）
- 停留阈值：EXPOSURE_STAY_MS（进入视区后需要持续停留的毫秒数）
- 去重口径：同一 item 只确认曝光一次（反复进出视区不重复上报）

## 事件入口：onViewableItemsChanged

FlatListScreen 将 onViewableItemsChanged 分成两条独立链路：
1) markHydratedImages(viewableItems)：图片惰性挂载（与曝光无耦合）
2) handleVisibilityChange(changed)：曝光状态机（只处理“变化的项”）

这样能减少长列表滚动时的计算量与 setState 次数。

## 曝光状态机（ref 层）

核心结构：
- exposureStateRef: Map<itemId, ExposureState>
  - enteredAt：进入视区时间戳
  - timerId：停留确认 timer
  - exposed：是否已确认曝光

handleVisibilityChange(changed) 的逻辑：
- isViewable=true：
  - 若已 exposed 或已有 timerId，直接忽略（去重/防抖）
  - 否则记录 enteredAt，并 setTimeout(EXPOSURE_STAY_MS)；到期调用 confirmExposure
- isViewable=false：
  - 若存在 timerId，clearTimeout（未达到停留阈值，不算曝光）
  - 若之前 exposed，保留 exposed 标记（timerId 置空）
  - 否则删除该 entry（回到初始状态）

confirmExposure(item, index, enteredAt) 做三件事：
- 标记 exposed（写入 exposureStateRef）
- 更新 UI：exposedIds(Set) 与 stats.exposureCount
- 上报 + 触发 lazy request：trackExposure(...) + requestFeedDetail(...)

埋点函数当前在 analytics.ts 中是 logger.info，占位但可替换为真实 SDK。

## 曝光后按需拉详情（lazy request）

目的：把“详情请求”从首屏/全量拉取变成“曝光后再拉取”，降低列表初始化压力。

去重与并发控制在 ref 层完成：
- requestedIdsRef：成功拉取过 detail 的 id（后续不再拉）
- inflightIdsRef：请求中的 id（避免重复并发）
- requestStatusRef：缓存每条的请求状态，避免重复 setState

requestFeedDetail(itemId, index, source) 流程：
- 若 requestedIdsRef 或 inflightIdsRef 命中，直接 return
- 进入请求：inflightIdsRef.add + updateDetailStatus('loading') + stats.requestCount++ + trackLazyRequest(start/retry)
- 成功：requestedIdsRef.add + detailMap 写入 + updateDetailStatus('success') + stats.successCount++ + trackLazyRequest(success, duration)
- 失败：updateDetailStatus('error') + stats.failureCount++ + trackLazyRequest(error, duration, message)

mockFeed.ts 会固定让部分 item 失败（index % 7 === 0），用于验证“只重试单条”能力。

## UI 如何呈现（FeedItem）

FeedItem.tsx 接收这些 props：
- isExposed：显示“已曝光/未曝光”
- detailStatus：显示“未请求/请求中/成功/失败”
- detail：成功后渲染详情内容
- onRetryDetail：失败时只重试当前 item，不刷新整表

页面顶部同时展示 Exposed / Requests / ReqFail 等指标，方便观察行为。

## 清理与重置

- 页面卸载：useEffect cleanup 调用 clearAllExposureTimers，避免 timer 泄漏。
- 下拉刷新：resetExposureSession 清理 timer + 清空 exposedIds/detail 状态与相关 ref，保证新一轮 session 的统计与去重正确。

## 验证清单

- 快速滑过某条（停留 < EXPOSURE_STAY_MS）：不应曝光。
- 停留达到阈值：应曝光一次，Exposed 计数 +1，并触发一次 lazy request。
- 失败条目：detailStatus=error；点击“重试详情请求”只增加该条 Requests，不影响其他 item。
- 重复进入视区：已曝光的 item 不重复曝光、不重复请求。
