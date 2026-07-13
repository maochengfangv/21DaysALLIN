# Feed 图片缓存机制说明

## 1. 方案选择

当前 Feed 场景采用的是 **方案 B：系统 HTTP cache + `Image.prefetch` 预热 + `Image.queryCache` 可观测缓存状态**。

选择这个方案的原因：

- 当前项目没有现成的专业图片缓存库。
- 目标是最小侵入，不为了一个 Demo 引入重量级三方依赖。
- React Native 内置 `Image` 已具备基础缓存能力，但默认行为不够“可解释、可验证、可展示”。
- 通过轻量封装，可以在不破坏现有列表性能结构的前提下，把缓存来源、加载态、失败态和重试机制都显式化。

## 2. 相关文件

- `src/pages/basics/feed/CachedImage.tsx`
  - Feed 图片统一渲染入口。
  - 封装缓存预热、缓存来源识别、loading/error/retry UI。

- `src/pages/basics/feed/FeedImageGrid.tsx`
  - 图片网格布局层。
  - 在 `shouldRenderImages=true` 后才真正挂载图片组件，并对当前 item 的图片执行预热。

- `src/pages/basics/feed/mockFeed.ts`
  - 模拟可复用图片 URI，便于观察缓存收益。
  - 注入固定失败图片 URI，便于验证 error/retry。

- `src/pages/basics/feed/types.ts`
  - 定义 `FeedImageCacheSource` 缓存来源类型。

## 3. 缓存机制设计

### 3.1 缓存层级

当前实现主要利用以下三层能力：

1. **系统 HTTP cache**
   - 在 `CachedImage` 中使用：

```tsx
source={{
  uri,
  cache: 'force-cache',
}}
```

作用：

- 优先复用系统已缓存图片。
- 减少重复下载。
- 回看同一张图时，降低重新请求和白屏闪烁概率。

2. **预热缓存（prefetch）**
   - 使用 `Image.prefetch(uri)`。
   - 在图片真正渲染前，先将资源请求送入系统缓存。

作用：

- 用户滑动到当前 item 时，尽量减少首次看到图片时的等待。
- 回滚上一个已看过区域时，命中率更高。

3. **缓存状态探测**
   - 使用 `Image.queryCache([uri])`。

作用：

- 判断图片当前是否命中 `memory / disk / disk+memory`。
- 给 Demo 增加可视化缓存标记，便于讲解和验证。

### 3.2 本地缓存注册表

`CachedImage.tsx` 内维护了两个轻量 Map：

- `cacheRegistry`
  - 记录当前 URI 已知的缓存来源。
  - 避免每次重复推断状态。

- `prefetchRegistry`
  - 记录当前正在执行的预热任务。
  - 避免同一 URI 被重复 `prefetch`。

这样做的意义：

- 让缓存行为可控，而不是完全依赖黑盒。
- 避免预热请求风暴。

## 4. 图片状态流转

### 4.1 loading

当图片开始加载，且本地尚未识别到已有缓存时：

- 显示灰底占位。
- 显示“缓存预热中...”文案。

目标：

- 防止图片区域直接白块。
- 在弱网下有明确反馈。

### 4.2 success

当图片加载成功：

- 进入成功态。
- 结合 `queryCache` 记录缓存来源。
- 左下角展示缓存标记：
  - `MEM`
  - `DISK`
  - `MEM+DISK`
  - `PREFETCH`
  - `HTTP`
  - `MISS`

说明：

- `HTTP` 表示本次成功显示，但未明确探测到 memory/disk 命中。
- `PREFETCH` 表示此前已经通过预热进入缓存链路。

### 4.3 error

当图片加载失败：

- 显示错误态覆盖层。
- 展示“加载失败 / 点击重试”。
- 点击后会清除该 URI 的本地错误记录，并重新触发加载。

目标：

- 不让失败图片直接留空。
- Demo 中可以稳定演示失败场景。

## 5. 与 Feed 渲染性能结构的配合

### 5.1 不破坏 `shouldRenderImages`

当前策略保持了原有的延迟挂载思路：

- `shouldRenderImages=false`
  - 不挂载真实图片组件。
  - 只显示轻量提示文案。

- `shouldRenderImages=true`
  - 才挂载 `CachedImage`。
  - 同时触发当前 item 图片的预热。

这意味着：

- 首屏不会因为整批图片同时挂载而抖动。
- 图片缓存能力只在真正需要时启用。

### 5.2 不破坏 `memo` 边界

- `FeedItem` 的 `memo` 结构保持不变。
- `FeedImageGrid` 仍然是 `memo` 组件。
- 单张图片的加载态、失败态、缓存态，主要在 `CachedImage` 内部自管理。

这样做的好处：

- 图片状态变化不会轻易带动整条 FeedItem 重渲染。
- 更符合长列表“局部状态局部消化”的性能原则。

## 6. 为什么 mock 数据可以验证缓存收益

在 `mockFeed.ts` 中做了两件事：

### 6.1 重复图片池

不是每条数据都生成全新图片 URL，而是从固定 `SHARED_IMAGE_POOL` 中取值。

效果：

- 多个 item 会复用相同 URI。
- 连续滚动和回看时，更容易命中缓存。
- 便于观察“同图二次出现”时加载更快、闪烁更少。

### 6.2 固定失败图片

对一部分 item 注入固定坏链：

```ts
const BROKEN_IMAGE_URI = 'https://invalid.feed-cache-demo.local/image-error.jpg';
```

效果：

- 可以稳定触发 error UI。
- 可以验证点击重试逻辑是否正常。

## 7. 当前可观察行为

进入 Feed 页面后，可以看到以下可验证现象：

1. 首次看到图片时：
   - 先出现 loading 占位。
   - 然后进入成功态。

2. 反复滚动回看相同图片时：
   - 更少重新下载。
   - 更少白屏/闪烁。
   - 缓存角标更容易出现 `MEM / DISK / PREFETCH`。

3. 遇到坏链图片时：
   - 出现“加载失败，点击重试”。
   - 可反复演示失败态和重试逻辑。

## 8. 验证步骤

### 8.1 进入页面

- 打开 `Basics -> FlatList Performance`。

### 8.2 验证缓存收益

1. 下滑几屏，先让一批图片加载完成。
2. 再快速滑回之前看过的区域。
3. 观察：
   - 图片再次出现时闪烁减少。
   - loading 占位减少。
   - 缓存角标更容易从 `MISS/HTTP` 变成 `MEM/DISK/PREFETCH`。

### 8.3 验证失败与重试

1. 找到首图加载失败的 item。
2. 观察错误态是否出现。
3. 点击“点击重试”。
4. 确认组件重新进入 loading -> error/success 流程。

### 8.4 弱网验证

可以在模拟器或测试设备上开启弱网：

- 首次加载会更明显看到 loading 占位。
- 已缓存图片回看时更容易直接显示。
- 未缓存图片失败时会稳定进入 error 态。

## 9. 面试讲解建议

这套方案的讲法可以概括成三层：

1. **先保滚动稳定**
   - 不把图片提早全部挂载。
   - 进入可视区后再启动图片渲染和预热。

2. **再做缓存收益**
   - 利用系统 HTTP cache。
   - 配合 `prefetch` 提高回看命中率。

3. **最后补齐可观测性**
   - 通过 `queryCache` 显式展示缓存来源。
   - 加入 loading/error/retry，让 Demo 更完整。

## 10. 当前限制

这套实现是轻量方案，也有明确边界：

- 缓存淘汰策略、磁盘上限、TTL 不可像专业图片库那样强控。
- `queryCache` 的平台表现可能存在差异，不同平台的缓存命中信息不一定完全一致。
- 当前预热粒度是“当前 item 图组”，还没有做更复杂的“下一屏批量调度预取”。
- loading 骨架是轻量灰底，不是复杂骨架动画，优先保证滚动稳定。

## 11. 结论

当前 Feed 图片缓存机制的核心目标不是“做最重的图片库能力”，而是：

- 最小改动接入
- 不破坏现有长列表性能结构
- 明确具备 loading / success / error / retry
- 让缓存行为可解释、可验证、可用于面试讲解

对于当前 Demo，这是一套足够工程化、同时又控制了复杂度的实现。
