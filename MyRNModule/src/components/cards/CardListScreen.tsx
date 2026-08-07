import React, { useCallback, useEffect, useState } from 'react';
import {
  FlatList,
  RefreshControl,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { BusinessCard } from './BusinessCard';
import type {
  BusinessCardPayload,
  CardListInitialProps,
} from './types';

let BusinessCardBridge: any = null;

try {
  BusinessCardBridge =
    require('../../../specs/NativeBusinessCardBridge').default;
} catch (_) {
  BusinessCardBridge = null;
}

const MOCK_CARDS: BusinessCardPayload[] = [
  {
    data: {
      cardId: 'card-featured-001',
      cardType: 0,
      title: 'React Native 新架构深度解析：Fabric 渲染管线',
      subtitle: '从 Shadow Tree → C++ Layout → Mount 完整链路',
      description:
        '本文从架构师视角拆解 RN 0.76+ 新架构的核心管线，对比旧架构的性能瓶颈与 Fabric 的解决思路。',
      coverUrl:
        'https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=800&auto=format&fit=crop',
      author: '老毛聊架构',
      tag: '精选',
      timestamp: Date.now() - 1000 * 60 * 25,
    },
    actions: [
      { id: 'act-1', title: '立即阅读', actionType: 0 },
      { id: 'act-2', title: '收藏', actionType: 1 },
    ],
  },
  {
    data: {
      cardId: 'card-news-002',
      cardType: 1,
      title: 'Swift Concurrency 实践：TaskGroup vs DispatchQueue',
      subtitle: '结构化并发在真实项目中的取舍',
      description:
        '结合 IM 消息拉取场景，对比两种并发模型在错误处理、取消传播、优先级继承上的差异。',
      coverUrl:
        'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop',
      author: 'Swift 周报',
      tag: '技术',
      timestamp: Date.now() - 1000 * 60 * 60 * 3,
    },
    actions: [
      { id: 'act-3', title: '查看详情', actionType: 0 },
      { id: 'act-4', title: '分享', actionType: 2 },
    ],
  },
  {
    data: {
      cardId: 'card-arch-003',
      cardType: 2,
      title: 'IM 热更新架构：Bundle 切换 + 回滚的工程实现',
      subtitle: '灰度发布 · 签名校验 · 崩溃回滚三位一体',
      description:
        '分享生产级 IM 应用的热更新治理方案：包体积 25MB 约束下如何做增量更新与版本兼容性。',
      coverUrl:
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&auto=format&fit=crop',
      author: '架构师之路',
      tag: '架构',
      timestamp: Date.now() - 1000 * 60 * 60 * 26,
    },
    actions: [
      { id: 'act-5', title: '订阅专栏', actionType: 0 },
      { id: 'act-6', title: '点赞', actionType: 3 },
    ],
  },
];

interface ScreenProps extends CardListInitialProps {}

const CardListScreen: React.FC<ScreenProps> = ({
  title,
  subtitle,
  cards: initialCards,
  enablePullRefresh = true,
  theme: propTheme,
}) => {
  const systemTheme = useColorScheme() ?? 'light';
  const theme = propTheme ?? (systemTheme === 'dark' ? 'dark' : 'light');

  const [cards, setCards] = useState<BusinessCardPayload[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingInitial, setLoadingInitial] = useState(true);

  const notifyCardPress = useCallback((cardId: string) => {
    if (BusinessCardBridge) {
      BusinessCardBridge.onCardPress?.(cardId);
    }
  }, []);

  const notifyActionPress = useCallback(
    (cardId: string, actionId: string, actionType: number) => {
      if (BusinessCardBridge) {
        BusinessCardBridge.onActionPress?.(
          cardId,
          actionId,
          actionType as any,
        );
      }
    },
    [],
  );

  const notifyExposure = useCallback((cardId: string, timestamp: number) => {
    if (BusinessCardBridge) {
      BusinessCardBridge.onExposure?.(cardId, timestamp as any);
    }
  }, []);

  useEffect(() => {
    let mounted = true;
    const bootstrap = async () => {
      let payload: string | null = null;
      if (BusinessCardBridge?.getInitialCards) {
        try {
          payload = await BusinessCardBridge.getInitialCards();
        } catch (_) {
          payload = null;
        }
      }

      if (!mounted) return;

      if (payload && payload !== '[]') {
        try {
          const parsed = JSON.parse(payload);
          if (Array.isArray(parsed) && parsed.length > 0) {
            setCards(parsed);
            setLoadingInitial(false);
            return;
          }
        } catch (_) {}
      }

      if (initialCards && initialCards.length > 0) {
        setCards(initialCards);
      } else {
        setCards(MOCK_CARDS);
      }
      setLoadingInitial(false);
    };
    bootstrap();
    return () => {
      mounted = false;
    };
  }, [initialCards]);

  const handleRefresh = useCallback(async () => {
    if (!enablePullRefresh) return;
    setRefreshing(true);
    await new Promise(r => setTimeout(r, 800));
    setCards(prev => [...prev].reverse());
    setRefreshing(false);
  }, [enablePullRefresh]);

  return (
    <SafeAreaView
      style={[
        styles.safeArea,
        theme === 'dark' ? styles.bgDark : styles.bgLight,
      ]}>
      <StatusBar barStyle={theme === 'dark' ? 'light-content' : 'dark-content'} />

      <View style={styles.header}>
        <Text
          style={[
            styles.headerTitle,
            theme === 'dark' ? styles.textLight : styles.textDark,
          ]}>
          {title ?? '发现 · 业务卡片'}
        </Text>
        {subtitle ? (
          <Text style={styles.headerSubtitle}>{subtitle}</Text>
        ) : null}
      </View>

      {loadingInitial ? (
        <View style={styles.loadingWrap}>
          <Text style={styles.loadingText}>卡片加载中...</Text>
        </View>
      ) : (
        <FlatList
          data={cards}
          keyExtractor={item => item.data.cardId}
          renderItem={({ item }) => (
            <BusinessCard
              data={item.data}
              actions={item.actions}
              theme={theme}
              onPress={notifyCardPress}
              onActionPress={notifyActionPress}
              onExposure={notifyExposure}
            />
          )}
          contentContainerStyle={styles.listContent}
          refreshControl={
            enablePullRefresh ? (
              <RefreshControl
                refreshing={refreshing}
                onRefresh={handleRefresh}
                tintColor={theme === 'dark' ? '#FFFFFF' : '#007AFF'}
              />
            ) : undefined
          }
          ListEmptyComponent={
            <View style={styles.emptyWrap}>
              <Text style={styles.emptyText}>暂无卡片</Text>
            </View>
          }
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: { flex: 1 },
  bgLight: { backgroundColor: '#F5F6FA' },
  bgDark: { backgroundColor: '#000000' },
  header: {
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 16,
  },
  headerTitle: {
    fontSize: 26,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  headerSubtitle: {
    marginTop: 4,
    fontSize: 14,
    color: '#94A3B8',
  },
  textLight: { color: '#F8FAFC' },
  textDark: { color: '#0F172A' },
  listContent: {
    paddingTop: 8,
    paddingBottom: 32,
  },
  loadingWrap: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 14,
    color: '#94A3B8',
  },
  emptyWrap: {
    paddingVertical: 80,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    color: '#94A3B8',
  },
});

export default CardListScreen;
