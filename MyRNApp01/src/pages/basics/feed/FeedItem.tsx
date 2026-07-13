import React, { memo, useCallback, useRef } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useImagePreview } from '../../../services/imagePreviewService';
import { ExpandableText } from './ExpandableText';
import { FeedImageGrid } from './FeedImageGrid';
import type { FeedDetailStatus, FeedItemData, FeedItemDetail } from './types';

function FeedItemInner({
  item,
  index,
  shouldRenderImages,
  isExposed,
  detailStatus,
  detail,
  onRetryDetail,
}: {
  item: FeedItemData;
  index: number;
  shouldRenderImages: boolean;
  isExposed: boolean;
  detailStatus: FeedDetailStatus;
  detail: FeedItemDetail | null;
  onRetryDetail?: (itemId: string, index: number) => void;
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
          ]}
        >
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

      <ExpandableText content={item.content} />

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

      <View style={styles.lazySection}>
        <View style={styles.statusRow}>
          <StatusChip
            label={isExposed ? '已曝光' : '未曝光'}
            tone={isExposed ? 'success' : 'neutral'}
          />
          <StatusChip
            label={getDetailStatusLabel(detailStatus)}
            tone={getDetailStatusTone(detailStatus)}
          />
        </View>

        {detailStatus === 'idle' ? (
          <Text style={styles.detailText}>
            进入视区并停留达到阈值后，再触发详情请求。
          </Text>
        ) : null}

        {detailStatus === 'loading' ? (
          <Text style={styles.detailText}>
            详情请求中，等待 lazy request 返回...
          </Text>
        ) : null}

        {detailStatus === 'success' && detail ? (
          <View style={styles.detailCard}>
            <Text style={styles.detailTitle}>
              {detail.hasLiked ? '已点赞用户视角' : '普通用户视角'}
            </Text>
            <Text style={styles.detailText}>{detail.detail}</Text>
            {detail.commentPreview.map((comment, commentIndex) => (
              <Text
                key={`${item.id}-comment-${commentIndex}`}
                style={styles.commentText}
              >
                - {comment}
              </Text>
            ))}
          </View>
        ) : null}

        {detailStatus === 'error' ? (
          <View style={styles.errorCard}>
            <Text style={styles.errorTitle}>详情请求失败</Text>
            <Text style={styles.detailText}>
              当前 item
              已曝光，但详情接口模拟失败。点击重试只会补这条数据，不会重刷整表。
            </Text>
            {onRetryDetail ? (
              <Pressable
                onPress={() => onRetryDetail(item.id, index)}
                style={styles.retryButton}
              >
                <Text style={styles.retryText}>重试详情请求</Text>
              </Pressable>
            ) : null}
          </View>
        ) : null}
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
  const { openImagePreview } = useImagePreview();

  const openPreview = useCallback(
    (targetIndex: number) => {
      openImagePreview({
        images,
        initialIndex: targetIndex,
      });
    },
    [images, openImagePreview],
  );

  return (
    <FeedImageGrid
      images={images}
      shouldRenderImages={shouldRenderImages}
      onPressImage={openPreview}
    />
  );
});

export const FeedItem = memo(
  FeedItemInner,
  (prevProps, nextProps) =>
    prevProps.item === nextProps.item &&
    prevProps.index === nextProps.index &&
    prevProps.shouldRenderImages === nextProps.shouldRenderImages &&
    prevProps.isExposed === nextProps.isExposed &&
    prevProps.detailStatus === nextProps.detailStatus &&
    prevProps.detail === nextProps.detail &&
    prevProps.onRetryDetail === nextProps.onRetryDetail,
);

function getDetailStatusLabel(status: FeedDetailStatus) {
  switch (status) {
    case 'loading':
      return '请求中';
    case 'success':
      return '详情已拉取';
    case 'error':
      return '请求失败';
    default:
      return '未请求';
  }
}

function getDetailStatusTone(status: FeedDetailStatus) {
  switch (status) {
    case 'loading':
      return 'brand';
    case 'success':
      return 'success';
    case 'error':
      return 'danger';
    default:
      return 'neutral';
  }
}

function StatusChip({
  label,
  tone,
}: {
  label: string;
  tone: 'neutral' | 'brand' | 'success' | 'danger';
}) {
  return (
    <View
      style={[
        styles.statusChip,
        tone === 'brand'
          ? styles.statusChipBrand
          : tone === 'success'
          ? styles.statusChipSuccess
          : tone === 'danger'
          ? styles.statusChipDanger
          : styles.statusChipNeutral,
      ]}
    >
      <Text
        style={[
          styles.statusChipText,
          tone === 'brand'
            ? styles.statusChipTextBrand
            : tone === 'success'
            ? styles.statusChipTextSuccess
            : tone === 'danger'
            ? styles.statusChipTextDanger
            : styles.statusChipTextNeutral,
        ]}
      >
        {label}
      </Text>
    </View>
  );
}

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
  mediaSection: {
    alignItems: 'flex-start',
  },
  lazySection: {
    gap: 8,
  },
  statusRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  statusChip: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  statusChipNeutral: {
    backgroundColor: '#F1F5F9',
  },
  statusChipBrand: {
    backgroundColor: '#DBEAFE',
  },
  statusChipSuccess: {
    backgroundColor: '#DCFCE7',
  },
  statusChipDanger: {
    backgroundColor: '#FEE2E2',
  },
  statusChipText: {
    fontSize: 11,
    fontWeight: '700',
  },
  statusChipTextNeutral: {
    color: '#475569',
  },
  statusChipTextBrand: {
    color: '#1D4ED8',
  },
  statusChipTextSuccess: {
    color: '#15803D',
  },
  statusChipTextDanger: {
    color: '#B91C1C',
  },
  textOnly: {
    fontSize: 12,
    color: '#64748B',
    backgroundColor: '#F8FAFC',
    borderRadius: 10,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  detailCard: {
    gap: 6,
    borderRadius: 12,
    backgroundColor: '#F8FAFC',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
    padding: 10,
  },
  errorCard: {
    gap: 8,
    borderRadius: 12,
    backgroundColor: '#FEF2F2',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#FECACA',
    padding: 10,
  },
  detailTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: '#0F172A',
  },
  detailText: {
    fontSize: 12,
    lineHeight: 18,
    color: '#475569',
  },
  commentText: {
    fontSize: 12,
    lineHeight: 18,
    color: '#334155',
  },
  errorTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: '#B91C1C',
  },
  retryButton: {
    alignSelf: 'flex-start',
    borderRadius: 999,
    backgroundColor: '#FCA5A5',
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  retryText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#7F1D1D',
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
