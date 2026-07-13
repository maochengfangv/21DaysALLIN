import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
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
  FEED_TOTAL_COUNT,
  fetchMockFeedPage,
} from './feed/mockFeed';
import type { FeedItemData } from './feed/types';

const SCREEN_POINTS = [
  'FeedItem 与 FeedImageGrid 都做 memo，避免父层状态抖动传导到整表',
  '图片进入可视区域后再挂载，并对超多图片做折叠，优先保证滚动流畅',
  '分页、刷新、keyExtractor、renderItem、onEndReached 都保持引用稳定',
];

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

  const currentPageRef = useRef(1);
  const refreshingRef = useRef(false);
  const loadingMoreRef = useRef(false);
  const hasMoreRef = useRef(true);

  const loadPage = useCallback(
    async (targetPage: number, mode: 'refresh' | 'append') => {
      if (mode === 'refresh') {
        if (refreshingRef.current) {
          return;
        }
        refreshingRef.current = true;
        setRefreshing(true);
        setHydratedImageIds(new Set());
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
    [],
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

  const onViewableItemsChanged = useRef(
    ({ viewableItems }: { viewableItems: ViewToken[] }) => {
      setHydratedImageIds(prevIds => {
        let changed = false;
        const nextIds = new Set(prevIds);

        viewableItems.forEach(viewToken => {
          const item = viewToken.item as FeedItemData | undefined;
          if (viewToken.isViewable && item?.images.length && !nextIds.has(item.id)) {
            nextIds.add(item.id);
            changed = true;
          }
        });

        return changed ? nextIds : prevIds;
      });
    },
  );

  const viewabilityConfig = useRef({
    itemVisiblePercentThreshold: 35,
    waitForInteraction: true,
  });

  const keyExtractor = useCallback((item: FeedItemData) => item.id, []);

  const renderItem = useCallback(
    ({ item, index }: ListRenderItemInfo<FeedItemData>) => {
      return (
        <FeedItem
          item={item}
          index={index}
          shouldRenderImages={hydratedImageIds.has(item.id)}
        />
      );
    },
    [hydratedImageIds],
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
          <MetricPill label="ScreenRender" value={screenRenderCountRef.current} />
        </View>

        <ResultCard title="面试讲解观察点">
          <Text style={styles.noteText}>
            当前数据量 {data.length}/{FEED_TOTAL_COUNT}，当前页累计图片 {totalImageCount}{' '}
            张。可观察 item 内的 render 次数：翻页时旧 item 不应轻易增长，只有新 cell
            或进入可视区触发图片挂载的 cell 才会变化。
          </Text>
        </ResultCard>

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
          initialNumToRender={6}
          maxToRenderPerBatch={4}
          windowSize={5}
          updateCellsBatchingPeriod={60}
          removeClippedSubviews={Platform.OS === 'android'}
          showsVerticalScrollIndicator={false}
          viewabilityConfig={viewabilityConfig.current}
          onViewableItemsChanged={onViewableItemsChanged.current}
          ListEmptyComponent={
            <Text style={styles.footerText}>
              {refreshing ? '正在拉取 feed 数据...' : '暂无数据'}
            </Text>
          }
          ListFooterComponent={
            <Text style={styles.footerText}>
              {footerText}
            </Text>
          }
        />
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
