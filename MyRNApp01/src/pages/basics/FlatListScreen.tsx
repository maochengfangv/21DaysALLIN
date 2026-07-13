import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Dimensions,
  FlatList,
  Platform,
  StyleSheet,
  Text,
  View,
  type ListRenderItemInfo,
  type ViewToken,
} from 'react-native';
import { Header } from '../../components/common/Header';
import {
  MetricPill,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';
import { FeedItem } from './feed/FeedItem';
import {
  FeedListFooterSkeleton,
  FeedListSkeleton,
} from './feed/FeedSkeleton';
import {
  FEED_TOTAL_COUNT,
  fetchMockFeedDetail,
  fetchMockFeedPage,
} from './feed/mockFeed';
import type {
  FeedDetailStatus,
  FeedItemData,
  FeedItemDetail,
} from './feed/types';
import { trackExposure, trackLazyRequest } from '../../services/analytics';

const SCREEN_POINTS = [
  'FeedItem 与 FeedImageGrid 都做 memo，避免父层状态抖动传导到整表',
  '图片进入可视区域后再挂载，并对超多图片做折叠，优先保证滚动流畅',
  '曝光埋点与 lazy request 用 ref 状态机去重，只在关键状态变化时刷新 UI',
  '分页、刷新、keyExtractor、renderItem、onEndReached 都保持引用稳定',
];

const EXPOSURE_VISIBLE_THRESHOLD = 35;
const EXPOSURE_STAY_MS = 300;
const SMALL_ANDROID_HEIGHT = 780;
const SMALL_ANDROID_WIDTH = 360;

type ExposureState = {
  enteredAt: number;
  timerId: ReturnType<typeof setTimeout> | null;
  exposed: boolean;
  index: number;
};

type FeedStats = {
  exposureCount: number;
  requestCount: number;
  successCount: number;
  failureCount: number;
};

export function FlatListScreen({ goBack }: ScreenProps) {
  const screenRenderCountRef = useRef(0);
  screenRenderCountRef.current += 1;

  const [data, setData] = useState<FeedItemData[]>([]);
  const [page, setPage] = useState(1);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [hydratedImageIds, setHydratedImageIds] = useState<Set<string>>(
    () => new Set(),
  );
  const [exposedIds, setExposedIds] = useState<Set<string>>(() => new Set());
  const [detailStatusMap, setDetailStatusMap] = useState<
    Record<string, FeedDetailStatus>
  >({});
  const [detailMap, setDetailMap] = useState<Record<string, FeedItemDetail>>(
    {},
  );
  const [stats, setStats] = useState<FeedStats>({
    exposureCount: 0,
    requestCount: 0,
    successCount: 0,
    failureCount: 0,
  });

  const listTuning = useMemo(() => {
    const { width, height } = Dimensions.get('window');
    const isAndroidLowTier =
      Platform.OS === 'android' &&
      (Math.min(width, height) <= SMALL_ANDROID_WIDTH ||
        Math.max(width, height) <= SMALL_ANDROID_HEIGHT);

    if (isAndroidLowTier) {
      return {
        tierLabel: 'Android Low Tier',
        initialNumToRender: 4,
        maxToRenderPerBatch: 2,
        windowSize: 3,
        updateCellsBatchingPeriod: 80,
      };
    }

    return {
      tierLabel: Platform.OS === 'android' ? 'Android Default' : 'iOS Default',
      initialNumToRender: 6,
      maxToRenderPerBatch: 4,
      windowSize: 5,
      updateCellsBatchingPeriod: 60,
    };
  }, []);

  const currentPageRef = useRef(1);
  const refreshingRef = useRef(false);
  const loadingMoreRef = useRef(false);
  const hasMoreRef = useRef(true);
  const exposureStateRef = useRef<Map<string, ExposureState>>(new Map());
  const requestedIdsRef = useRef<Set<string>>(new Set());
  const inflightIdsRef = useRef<Set<string>>(new Set());
  const requestStatusRef = useRef<Map<string, FeedDetailStatus>>(new Map());

  const clearAllExposureTimers = useCallback(() => {
    exposureStateRef.current.forEach(entry => {
      if (entry.timerId) {
        clearTimeout(entry.timerId);
      }
    });
    exposureStateRef.current.clear();
  }, []);

  const resetExposureSession = useCallback(() => {
    clearAllExposureTimers();
    requestedIdsRef.current.clear();
    inflightIdsRef.current.clear();
    requestStatusRef.current.clear();
    setExposedIds(new Set());
    setDetailStatusMap({});
    setDetailMap({});
    setStats({
      exposureCount: 0,
      requestCount: 0,
      successCount: 0,
      failureCount: 0,
    });
  }, [clearAllExposureTimers]);

  const updateDetailStatus = useCallback(
    (itemId: string, status: FeedDetailStatus) => {
      if (requestStatusRef.current.get(itemId) === status) {
        return;
      }

      requestStatusRef.current.set(itemId, status);
      setDetailStatusMap(prev => {
        if (prev[itemId] === status) {
          return prev;
        }

        return {
          ...prev,
          [itemId]: status,
        };
      });
    },
    [],
  );

  const requestFeedDetail = useCallback(
    async (
      itemId: string,
      index: number,
      source: 'exposure' | 'retry' = 'exposure',
    ) => {
      if (
        requestedIdsRef.current.has(itemId) ||
        inflightIdsRef.current.has(itemId)
      ) {
        return;
      }

      inflightIdsRef.current.add(itemId);
      updateDetailStatus(itemId, 'loading');
      setStats(prev => ({
        ...prev,
        requestCount: prev.requestCount + 1,
      }));

      trackLazyRequest({
        itemId,
        index,
        timestamp: Date.now(),
        status: source === 'retry' ? 'retry' : 'start',
      });

      const startedAt = Date.now();

      try {
        const detail = await fetchMockFeedDetail(itemId);
        inflightIdsRef.current.delete(itemId);
        requestedIdsRef.current.add(itemId);
        setDetailMap(prev => ({
          ...prev,
          [itemId]: detail,
        }));
        updateDetailStatus(itemId, 'success');
        setStats(prev => ({
          ...prev,
          successCount: prev.successCount + 1,
        }));
        trackLazyRequest({
          itemId,
          index,
          timestamp: Date.now(),
          status: 'success',
          durationMs: Date.now() - startedAt,
        });
      } catch (error) {
        inflightIdsRef.current.delete(itemId);
        updateDetailStatus(itemId, 'error');
        setStats(prev => ({
          ...prev,
          failureCount: prev.failureCount + 1,
        }));
        trackLazyRequest({
          itemId,
          index,
          timestamp: Date.now(),
          status: 'error',
          durationMs: Date.now() - startedAt,
          errorMessage: error instanceof Error ? error.message : String(error),
        });
      }
    },
    [updateDetailStatus],
  );

  const confirmExposure = useCallback(
    (item: FeedItemData, index: number, enteredAt: number) => {
      const previous = exposureStateRef.current.get(item.id);

      if (previous?.exposed) {
        return;
      }

      exposureStateRef.current.set(item.id, {
        enteredAt,
        timerId: null,
        exposed: true,
        index,
      });

      setExposedIds(prev => {
        if (prev.has(item.id)) {
          return prev;
        }
        const next = new Set(prev);
        next.add(item.id);
        return next;
      });
      setStats(prev => ({
        ...prev,
        exposureCount: prev.exposureCount + 1,
      }));

      trackExposure({
        itemId: item.id,
        index,
        timestamp: Date.now(),
        visibleThreshold: EXPOSURE_VISIBLE_THRESHOLD,
        stayMs: Date.now() - enteredAt,
      });

      requestFeedDetail(item.id, index, 'exposure').catch(() => undefined);
    },
    [requestFeedDetail],
  );

  const loadPage = useCallback(
    async (targetPage: number, mode: 'refresh' | 'append') => {
      if (mode === 'refresh') {
        if (refreshingRef.current) {
          return;
        }
        refreshingRef.current = true;
        setRefreshing(true);
        setHydratedImageIds(new Set());
        resetExposureSession();
      } else {
        if (
          loadingMoreRef.current ||
          refreshingRef.current ||
          !hasMoreRef.current
        ) {
          return;
        }
        loadingMoreRef.current = true;
        setLoadingMore(true);
      }

      try {
        const response = await fetchMockFeedPage(targetPage);
        currentPageRef.current = response.page;
        hasMoreRef.current = response.hasMore;

        setData(prevData =>
          mode === 'refresh' ? response.list : [...prevData, ...response.list],
        );
        setPage(response.page);
        setHasMore(response.hasMore);
      } finally {
        if (mode === 'refresh') {
          refreshingRef.current = false;
          setRefreshing(false);
        } else {
          loadingMoreRef.current = false;
          setLoadingMore(false);
        }
      }
    },
    [resetExposureSession],
  );

  useEffect(() => {
    loadPage(1, 'refresh').catch(() => undefined);
  }, [loadPage]);

  const onRefresh = useCallback(() => {
    loadPage(1, 'refresh').catch(() => undefined);
  }, [loadPage]);

  const onEndReached = useCallback(() => {
    if (!hasMoreRef.current) {
      return;
    }
    loadPage(currentPageRef.current + 1, 'append').catch(() => undefined);
  }, [loadPage]);

  useEffect(() => {
    return () => {
      clearAllExposureTimers();
    };
  }, [clearAllExposureTimers]);

  const markHydratedImages = useCallback((viewableItems: ViewToken[]) => {
    setHydratedImageIds(prevIds => {
      let changed = false;
      const nextIds = new Set(prevIds);

      viewableItems.forEach(viewToken => {
        const item = viewToken.item as FeedItemData | undefined;
        if (
          viewToken.isViewable &&
          item?.images.length &&
          !nextIds.has(item.id)
        ) {
          nextIds.add(item.id);
          changed = true;
        }
      });

      return changed ? nextIds : prevIds;
    });
  }, []);

  const handleVisibilityChange = useCallback(
    (changedItems: ViewToken[]) => {
      changedItems.forEach(viewToken => {
        const item = viewToken.item as FeedItemData | undefined;
        if (!item) {
          return;
        }

        const previousState = exposureStateRef.current.get(item.id);

        if (viewToken.isViewable) {
          if (previousState?.exposed || previousState?.timerId) {
            return;
          }

          const enteredAt = Date.now();
          const timerId = setTimeout(() => {
            confirmExposure(item, viewToken.index ?? 0, enteredAt);
          }, EXPOSURE_STAY_MS);

          exposureStateRef.current.set(item.id, {
            enteredAt,
            timerId,
            exposed: false,
            index: viewToken.index ?? 0,
          });
          return;
        }

        if (previousState?.timerId) {
          clearTimeout(previousState.timerId);
        }

        if (previousState?.exposed) {
          exposureStateRef.current.set(item.id, {
            ...previousState,
            timerId: null,
          });
        } else {
          exposureStateRef.current.delete(item.id);
        }
      });
    },
    [confirmExposure],
  );

  const onViewableItemsChanged = useRef(
    ({
      viewableItems,
      changed,
    }: {
      viewableItems: ViewToken[];
      changed: ViewToken[];
    }) => {
      markHydratedImages(viewableItems);
      handleVisibilityChange(changed);
    },
  );

  const viewabilityConfig = useRef({
    itemVisiblePercentThreshold: EXPOSURE_VISIBLE_THRESHOLD,
    waitForInteraction: true,
  });

  const keyExtractor = useCallback((item: FeedItemData) => item.id, []);

  const retryFeedDetail = useCallback(
    (itemId: string, itemIndex: number) => {
      requestFeedDetail(itemId, itemIndex, 'retry').catch(() => undefined);
    },
    [requestFeedDetail],
  );

  const renderItem = useCallback(
    ({ item, index }: ListRenderItemInfo<FeedItemData>) => {
      return (
        <FeedItem
          item={item}
          index={index}
          shouldRenderImages={hydratedImageIds.has(item.id)}
          isExposed={exposedIds.has(item.id)}
          detailStatus={detailStatusMap[item.id] ?? 'idle'}
          detail={detailMap[item.id] ?? null}
          onRetryDetail={retryFeedDetail}
        />
      );
    },
    [detailMap, detailStatusMap, exposedIds, hydratedImageIds, retryFeedDetail],
  );

  const totalImageCount = useMemo(() => {
    return data.reduce((sum, item) => sum + item.images.length, 0);
  }, [data]);

  const footerText = useMemo(() => {
    if (loadingMore) {
      return '分页加载中...';
    }
    if (!hasMore && data.length > 0) {
      return '已加载到末尾';
    }
    return '继续上滑触发下一页';
  }, [data.length, hasMore, loadingMore]);

  const initialLoading = data.length === 0 && refreshing;
  const appendLoading = data.length > 0 && loadingMore;

  return (
    <>
      <Header title="FlatList Performance" goBack={goBack} />
      <ScreenContainer
        scroll={false}
        title="Feed Flow Performance Demo"
        summary="把简单列表升级成类似朋友圈的 feed 流：不定图数量、分页刷新、惰性图片挂载和稳定的 item 渲染边界。"
        points={SCREEN_POINTS}
        style={demoStyles.noBottomPadding}
      >
        <View style={uiStyles.row}>
          <MetricPill label="Count" value={data.length} />
          <MetricPill label="Page" value={page} />
          <MetricPill label="LoadingMore" value={String(loadingMore)} />
          <MetricPill label="HydratedRows" value={hydratedImageIds.size} />
          <MetricPill label="Exposed" value={stats.exposureCount} />
          <MetricPill label="Requests" value={stats.requestCount} />
          <MetricPill label="ReqFail" value={stats.failureCount} />
          <MetricPill label="ListTier" value={listTuning.tierLabel} />
          <MetricPill
            label="ScreenRender"
            value={screenRenderCountRef.current}
          />
        </View>

        <ResultCard title="面试讲解观察点">
          <Text style={styles.noteText}>
            当前数据量 {data.length}/{FEED_TOTAL_COUNT}，当前页累计图片{' '}
            {totalImageCount} 张。可观察 item 内的 render 次数：翻页时旧 item
            不应轻易增长，只有新 cell 或进入可视区触发图片挂载的 cell 才会变化。
          </Text>
          <Text style={styles.noteText}>
            曝光阈值为可见面积 {EXPOSURE_VISIBLE_THRESHOLD}% + 停留{' '}
            {EXPOSURE_STAY_MS}ms。曝光后只上报一次，并按需拉取
            detail，失败时只重试单条。
          </Text>
          <Text style={styles.noteText}>
            首屏使用静态骨架屏承接第一页 loading，分页时只在底部追加
            skeleton，避免旧内容闪烁。
          </Text>
        </ResultCard>

        {initialLoading ? (
          <FeedListSkeleton count={listTuning.initialNumToRender} />
        ) : (
          <FlatList
            style={styles.list}
            data={data}
            keyExtractor={keyExtractor}
            renderItem={renderItem}
            contentContainerStyle={styles.listContent}
            refreshing={refreshing}
            onRefresh={onRefresh}
            onEndReachedThreshold={0.4}
            onEndReached={onEndReached}
            initialNumToRender={listTuning.initialNumToRender}
            maxToRenderPerBatch={listTuning.maxToRenderPerBatch}
            windowSize={listTuning.windowSize}
            updateCellsBatchingPeriod={listTuning.updateCellsBatchingPeriod}
            removeClippedSubviews={Platform.OS === 'android'}
            showsVerticalScrollIndicator={false}
            viewabilityConfig={viewabilityConfig.current}
            onViewableItemsChanged={onViewableItemsChanged.current}
            ListEmptyComponent={<Text style={styles.footerText}>暂无数据</Text>}
            ListFooterComponent={
              appendLoading ? (
                <FeedListFooterSkeleton />
              ) : (
                <Text style={styles.footerText}>{footerText}</Text>
              )
            }
          />
        )}
      </ScreenContainer>
    </>
  );
}

const styles = StyleSheet.create({
  list: {
    flex: 1,
    marginTop: 4,
  },
  listContent: {
    paddingBottom: 24,
    gap: 10,
  },
  noteText: {
    fontSize: 13,
    lineHeight: 19,
    color: '#334155',
  },
  footerText: {
    textAlign: 'center',
    color: '#64748B',
    paddingVertical: 12,
    fontSize: 12,
  },
});
