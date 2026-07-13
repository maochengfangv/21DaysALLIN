import React, { memo, useCallback, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { ImagePreviewModal } from '../../../components/common/ImagePreviewModal';
import { FeedImageGrid } from './FeedImageGrid';
import type { FeedItemData } from './types';

function FeedItemInner({
  item,
  index,
  shouldRenderImages,
}: {
  item: FeedItemData;
  index: number;
  shouldRenderImages: boolean;
}) {
  const renderCountRef = useRef(0);
  renderCountRef.current += 1;
  const hasImages = item.images.length > 0;

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View
          style={[
            styles.avatar,
            {
              backgroundColor: item.author.avatarColor,
            },
          ]}>
          <Text style={styles.avatarText}>{item.author.name.slice(0, 1)}</Text>
        </View>

        <View style={styles.headerContent}>
          <View style={styles.nameRow}>
            <Text style={styles.name}>{item.author.name}</Text>
            <Text style={styles.badge}>{item.author.badge}</Text>
          </View>
          <Text style={styles.publishAt}>{item.publishAt}</Text>
        </View>

        <Text style={styles.index}>#{index + 1}</Text>
      </View>

      <Text style={styles.content}>{item.content}</Text>

      <View style={styles.mediaSection}>
        {hasImages ? (
          <FeedItemMedia
            images={item.images}
            shouldRenderImages={shouldRenderImages}
          />
        ) : (
          <Text style={styles.textOnly}>纯文本动态，无图片渲染开销</Text>
        )}
      </View>

      <View style={styles.footer}>
        <Text style={styles.meta}>
          {item.likeCount} 赞 · {item.commentCount} 评论
        </Text>
        <Text style={styles.meta}>
          render #{renderCountRef.current} · images {item.images.length}
        </Text>
      </View>
    </View>
  );
}

const FeedItemMedia = memo(function FeedItemMediaInner({
  images,
  shouldRenderImages,
}: {
  images: string[];
  shouldRenderImages: boolean;
}) {
  const [previewVisible, setPreviewVisible] = useState(false);
  const [previewIndex, setPreviewIndex] = useState(0);

  const openPreview = useCallback((targetIndex: number) => {
    setPreviewIndex(targetIndex);
    setPreviewVisible(true);
  }, []);

  const closePreview = useCallback(() => {
    setPreviewVisible(false);
  }, []);

  return (
    <>
      <FeedImageGrid
        images={images}
        shouldRenderImages={shouldRenderImages}
        onPressImage={openPreview}
      />

      <ImagePreviewModal
        visible={previewVisible}
        images={images}
        initialIndex={previewIndex}
        onClose={closePreview}
      />
    </>
  );
});

export const FeedItem = memo(
  FeedItemInner,
  (prevProps, nextProps) =>
    prevProps.item === nextProps.item &&
    prevProps.index === nextProps.index &&
    prevProps.shouldRenderImages === nextProps.shouldRenderImages,
);

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 14,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
    gap: 10,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  },
  headerContent: {
    flex: 1,
    gap: 3,
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  name: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
  },
  badge: {
    fontSize: 11,
    color: '#1D4ED8',
    backgroundColor: '#DBEAFE',
    borderRadius: 999,
    paddingHorizontal: 7,
    paddingVertical: 2,
    overflow: 'hidden',
  },
  publishAt: {
    fontSize: 12,
    color: '#64748B',
  },
  index: {
    fontSize: 12,
    color: '#2563EB',
    fontWeight: '700',
  },
  content: {
    fontSize: 14,
    lineHeight: 21,
    color: '#1E293B',
  },
  mediaSection: {
    alignItems: 'flex-start',
  },
  textOnly: {
    fontSize: 12,
    color: '#64748B',
    backgroundColor: '#F8FAFC',
    borderRadius: 10,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: 8,
  },
  meta: {
    fontSize: 12,
    color: '#475569',
  },
});
