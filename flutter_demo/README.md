# Flutter 长列表性能优化 Demo

## 项目概述

通过 **Baseline（未优化）vs Optimized（已优化）** 对比，展示 Flutter 长列表渲染性能优化的完整方法论。在 Profile 模式 + DevTools Performance 面板下可直观对比优化效果。

## 项目结构

```
flutter_demo/
├── lib/
│   ├── main.dart                          # App 入口，全局 PerformanceOverlay 开关
│   ├── data/
│   │   ├── item_model.dart                # 数据模型
│   │   └── item_repository.dart           # 数据层：模拟分页接口 + ChangeNotifier 状态管理
│   ├── pages/
│   │   ├── baseline_list_page.dart        # Baseline：200k 条目，故意注入卡顿因素
│   │   └── optimized_list_page.dart       # Optimized：懒构建 + 分页 + 多重优化策略
│   ├── utils/
│   │   └── scroll_activity_notifier.dart  # 滚动状态检测工具（防抖 + ValueNotifier）
│   └── widgets/
│       ├── list_item_baseline.dart        # 未优化 Item：重 Widget 树 + Image.network 无控制
│       └── list_item_optimized.dart       # 已优化 Item：RepaintBoundary + 图片缓存 + 滚动占位
└── pubspec.yaml
```

## 技术要点

### 一、Baseline 卡顿因素（故意注入）

| 问题 | 实现 | 后果 |
|------|------|------|
| 整页频繁 setState | `Timer.periodic(1s)` 更新 tick 和 highlightId | 每次 tick 触发页面级 `build()`，20 万条目全部重建 |
| 超大数据集 | `ListView.builder(itemCount: 200000)` 静态计数 | 大量不可见 Widget 仍在参与 diff/reconcile |
| 重型 Item 树 | `BaselineListItem` 包含 `Row > Column > Row > IconButton` 多层嵌套 + `Image.network` | 单帧 Build 耗时长 |
| 网络图片无约束 | `Image.network(url, width: 72, height: 72)` 未设 `cacheWidth/cacheHeight` | 解码大图耗内存，garbage collection 引发 Jank |
| 点赞联动全局刷新 | `setState(() => _highlightId = id)` | 点击一个 Item 的心形图标触发整页 rebuild |

### 二、Optimized 优化策略

#### 1. Sliver 懒构建 + 分页

```dart
CustomScrollView(
  slivers: [
    SliverList(
      delegate: SliverChildBuilderDelegate(
        childCount: items.length + 1,   // 只构建可见区域 + 缓冲
        addRepaintBoundaries: false,    // Sliver 已自带边界
        addAutomaticKeepAlives: false,  // 不保留不可见 Item 状态
      ),
    ),
  ],
)
```

#### 2. RepaintBoundary 隔离重绘

```dart
// 每个 Item 包裹 RepaintBoundary，点赞状态变化只重绘当前 Item
RepaintBoundary(child: OptimizedListItem(...))
```

#### 3. 局部状态：ValueNotifier 替代 setState

```dart
// ItemStore 中每个 Item 的点赞状态独立为 ValueNotifier
ValueNotifier<bool> likeNotifierFor(int itemId) {
  return _likeNotifiers.putIfAbsent(itemId, () => ValueNotifier<bool>(false));
}

// UI 层使用 ValueListenableBuilder 监听单个状态，仅为对应 _Actions 组件重建
ValueListenableBuilder<bool>(
  valueListenable: likedListenable,
  builder: (context, liked, _) => IconButton(...),
)
```

#### 4. 滚动感知图片加载

```dart
// 滚动中：仅展示占位色块，不上屏真实图片
if (isScrolling) {
  return ColoredBox(color: theme.colorScheme.surface, child: Icon(...));
}

// 停止滚动后：加载 CachedNetworkImage
return CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: cacheSize,    // 按实际尺寸缓存，避免解码大图
  memCacheHeight: cacheSize,
  filterQuality: FilterQuality.low,  // 降低渲染质量，提升帧率
);
```

#### 5. 固定尺寸 URL + 缓存尺寸控制

```dart
final url = 'https://picsum.photos/seed/$id/80/80';  // 服务端按需返回 80x80 图
final dpr = MediaQuery.devicePixelRatioOf(context);
final cacheSize = (56 * dpr).round();                  // 按显示尺寸 × DPR 计算缓存尺寸
```

#### 6. 触底/停止防抖

```dart
// 滚动停止 200ms 后才标记 isScrolling = false，避免快速滑动时反复切换
class ScrollActivityNotifier {
  final Duration idleDebounce = Duration(milliseconds: 180);
  // 滚动结束时启动 Timer，超时后才设 isScrolling = false
}

// 触底加载更多有 120ms 防抖
_loadMoreDebounce = Timer(Duration(milliseconds: 120), _maybeLoadMore);
```

#### 7. 帧耗时统计（_FrameJankAggregator）

```dart
// 每 3 秒汇总输出帧耗时数据到 debugPrint
[_FrameJankAggregator]
Frames=120 avgBuild=4.2ms avgRaster=3.1ms jank=2 (1.7%)
```

### 三、State 管理链路

```
ItemStore (ChangeNotifier)
  ├── items: List<ItemModel>           → AnimatedBuilder 监听，控制 SliverList
  ├── isLoading / hasMore              → _LoadMoreFooter 控制加载/重试 UI
  └── _likeNotifiers: Map<int, ValueNotifier<bool>>
       └── 每个 Item 独立 → _Actions 组件 ValueListenableBuilder 监听

ScrollActivityNotifier
  └── isScrolling: ValueNotifier<bool> → _Thumb 组件 ValueListenableBuilder 监听
```

### 四、跨平台支持

| 平台 | 状态 |
|------|------|
| iOS | 已配置 |
| Android | 已配置 |
| macOS | 已配置 |
| Linux | 已配置 |
| Windows | 已配置 |
| Web | 已配置 |

## 运行与对比

```bash
# Profile 模式运行（推荐）
flutter run --profile

# Release 模式
flutter run --release
```

1. 进入 Basline（未优化）页面，打开 PerformanceOverlay 开关，观察频繁 Jank
2. 进入 Optimized（已优化）页面，同样操作对比
3. 在 DevTools → Performance 面板分别录制一次快速滑动，对比 Build/Raster 耗时分布

## 对比清单

| 维度 | Baseline | Optimized |
|------|----------|-----------|
| 数据集 | 200,000 条静态 | 20,000 条分页（50/页） |
| 列表构建 | ListView.builder | CustomScrollView + SliverList |
| 重绘隔离 | 无 | RepaintBoundary 每个 Item |
| 状态更新 | setState 整页 | ValueNotifier 局部 |
| 图片加载 | Image.network 无缓存 | CachedNetworkImage + memCache |
| 滚动中策略 | 无感知，一直加载 | 占位 → 停止后加载真图 |
| 图片尺寸 | 72x72 无解码控制 | 56x56 × DPR 精确缓存 |
| 帧监控 | 无 | _FrameJankAggregator 每 3s 汇总 |
| 防抖 | 无 | 滚动停止 180ms + 加载 120ms |

## 技术标签

`Flutter` `性能优化` `长列表` `Sliver` `RepaintBoundary` `ValueNotifier` `CachedNetworkImage` `FrameTiming` `防抖` `惰性加载`
