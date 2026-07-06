import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/item_repository.dart';
import '../main.dart';
import '../utils/scroll_activity_notifier.dart';
import '../widgets/list_item_optimized.dart';


class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final Future<void> Function() onRetry;

  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('已加载到上限')),
      );
    }

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: TextButton(
          onPressed: () => onRetry(),
          child: const Text('继续加载'),
        ),
      ),
    );
  }
}

class _FrameJankAggregator {
  final String label;

  final List<FrameTiming> _buffer = <FrameTiming>[];
  Timer? _flushTimer;
  bool _started = false;

  _FrameJankAggregator({required this.label});

  void start() {
    if (_started) return;
    _started = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => _flush());
  }

  void stop() {
    if (!_started) return;
    _started = false;

    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _flushTimer?.cancel();
    _flushTimer = null;
    _flush();
  }

  void _onTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
  }

  void _flush() {
    if (_buffer.isEmpty) return;

    final frames = List<FrameTiming>.from(_buffer);
    _buffer.clear();

    const budgetMs = 16.67;

    double sumBuildMs = 0;
    double sumRasterMs = 0;
    int jankCount = 0;

    for (final t in frames) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      sumBuildMs += buildMs;
      sumRasterMs += rasterMs;
      if (buildMs > budgetMs || rasterMs > budgetMs) {
        jankCount++;
      }
    }

    final n = frames.length;
    final avgBuild = sumBuildMs / n;
    final avgRaster = sumRasterMs / n;
    final jankRate = (jankCount / n) * 100;

    debugPrint(
      '[$label][FrameStats] frames=$n avgBuild=${avgBuild.toStringAsFixed(2)}ms '
      'avgRaster=${avgRaster.toStringAsFixed(2)}ms jank=$jankCount (${jankRate.toStringAsFixed(1)}%)',
    );
  }
}

class OptimizedListPage extends StatefulWidget {
  static const routeName = '/optimized';
  const OptimizedListPage({super.key});

  @override
  State<OptimizedListPage> createState() => _OptimizedListPageState();
}

class _OptimizedListPageState extends State<OptimizedListPage> {
  late final ScrollController _controller;
  late final ScrollActivityNotifier _scrollActivity;
  late final ItemStore _store;

  Timer? _loadMoreDebounce;
  late final _FrameJankAggregator _jankAggregator;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _scrollActivity = ScrollActivityNotifier(idleDebounce: const Duration(milliseconds: 200));
    _store = ItemStore(pageSize: 50, totalLimit: 20000, repository: const ItemRepository(simulatedDelay: Duration(milliseconds: 350)));
    _jankAggregator = _FrameJankAggregator(label: 'Optimized');
    _jankAggregator.start();
    unawaited(_store.loadInitial());

    _controller.addListener(() {
      _loadMoreDebounce?.cancel();
      _loadMoreDebounce = Timer(const Duration(milliseconds: 120), _maybeLoadMore);
    });
  }

  void _maybeLoadMore() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.extentAfter < 900) {
      unawaited(_store.loadNextPage());
    }
  }

  @override
  void dispose() {
    _loadMoreDebounce?.cancel();
    _controller.dispose();
    _scrollActivity.dispose();
    _store.dispose();
    _jankAggregator.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: _scrollActivity.handleScrollNotification,
      child: Scaffold(
        body: CustomScrollView(
          controller: _controller,
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Optimized（已优化）'),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: performanceOverlayEnabled,
                  builder: (context, enabled, _) {
                    return Row(
                      children: [
                        const Text('Overlay'),
                        Switch(
                          value: enabled,
                          onChanged: (v) => performanceOverlayEnabled.value = v,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: AnimatedBuilder(
                  animation: _store,
                  builder: (context, _) {
                    final text = 'items=${_store.items.length}  loading=${_store.isLoading}  hasMore=${_store.hasMore}';
                    return Container(
                      alignment: Alignment.centerLeft,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Text(text),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    '关键点：Sliver 懒构建 + 分页；Item RepaintBoundary；局部状态(ValueNotifier)；CachedNetworkImage；固定尺寸URL+memCacheWidth/Height；滚动中占位/停止后加载真图；触底/停止均做防抖；帧耗时汇总打印。',
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _store,
              builder: (context, _) {
                final items = _store.items;

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= items.length) {
                        return _LoadMoreFooter(
                          isLoading: _store.isLoading,
                          hasMore: _store.hasMore,
                          onRetry: _store.loadNextPage,
                        );
                      }

                      final model = items[index];
                      final likedNotifier = _store.likeNotifierFor(model.id);

                      return OptimizedListItem(
                        key: ValueKey<int>(model.id),
                        item: model,
                        isScrollingListenable: _scrollActivity.isScrolling,
                        likedListenable: likedNotifier,
                        onToggleLiked: () => likedNotifier.value = !likedNotifier.value,
                      );
                    },
                    childCount: items.length + 1,
                    addRepaintBoundaries: false,
                    addAutomaticKeepAlives: false,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}