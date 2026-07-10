import React, { memo, useEffect, useState } from 'react';
import { FlatList, Text, View } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  MetricPill,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { fetchSkillPage, type SkillListItem } from '../../services/mockApi';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function FlatListScreen({ goBack }: ScreenProps) {
  const [data, setData] = useState<SkillListItem[]>([]);
  const [page, setPage] = useState(1);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);

  const loadFirstPage = async () => {
    setRefreshing(true);
    const next = await fetchSkillPage(1);
    setData(next);
    setPage(1);
    setRefreshing(false);
  };

  const loadMore = async () => {
    if (loadingMore) {
      return;
    }
    setLoadingMore(true);
    const nextPage = page + 1;
    const next = await fetchSkillPage(nextPage);
    setData(prev => [...prev, ...next]);
    setPage(nextPage);
    setLoadingMore(false);
  };

  useEffect(() => {
    loadFirstPage();
  }, []);

  return (
    <>
      <Header title="FlatList Performance" goBack={goBack} />
      <ScreenContainer
        scroll={false}
        title="FlatList Performance Demo"
        summary="展示长列表性能要点：稳定 key、memo item、分页加载、下拉刷新。"
        points={[
          'item 使用 memo，避免父层小改动导致整表重渲染',
          'onEndReached 做分页 mock',
          'refreshing + onRefresh 做下拉刷新',
        ]}
        style={demoStyles.noBottomPadding}
      >
        <View style={uiStyles.row}>
          <MetricPill label="Count" value={data.length} />
          <MetricPill label="Page" value={page} />
          <MetricPill label="LoadingMore" value={String(loadingMore)} />
        </View>

        <FlatList
          data={data}
          keyExtractor={item => item.id}
          renderItem={({ item, index }) => (
            <MemoListItem item={item} index={index} />
          )}
          contentContainerStyle={demoStyles.listContent}
          refreshing={refreshing}
          onRefresh={loadFirstPage}
          onEndReachedThreshold={0.3}
          onEndReached={loadMore}
          ListFooterComponent={
            <Text style={demoStyles.footerText}>
              {loadingMore ? '分页加载中...' : '上拉触发下一页'}
            </Text>
          }
        />
      </ScreenContainer>
    </>
  );
}

const MemoListItem = memo(
  ({ item, index }: { item: SkillListItem; index: number }) => {
    return (
      <View style={demoStyles.listItem}>
        <Text style={demoStyles.listIndex}>{index + 1}</Text>
        <View style={demoStyles.flexOne}>
          <Text style={demoStyles.catalogTitle}>{item.title}</Text>
          <Text style={demoStyles.catalogSubtitle}>{item.description}</Text>
        </View>
      </View>
    );
  },
);
