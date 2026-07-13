import React, {memo} from 'react';
import {
  ScrollView,
  StyleSheet,
  View,
  type DimensionValue,
} from 'react-native';

const DEFAULT_INITIAL_SKELETON_COUNT = 4;
const DEFAULT_APPEND_SKELETON_COUNT = 2;

function Bone({
  width,
  height,
  radius = 8,
}: {
  width: DimensionValue;
  height: number;
  radius?: number;
}) {
  return <View style={[styles.bone, {width, height, borderRadius: radius}]} />;
}

export const FeedItemSkeleton = memo(function FeedItemSkeletonInner({
  variant = 'initial',
}: {
  variant?: 'initial' | 'append';
}) {
  const showLargeMedia = variant === 'initial';

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <Bone width={42} height={42} radius={21} />
        <View style={styles.headerContent}>
          <Bone width="42%" height={14} />
          <Bone width="28%" height={10} />
        </View>
        <Bone width={28} height={12} />
      </View>

      <View style={styles.textBlock}>
        <Bone width="96%" height={12} />
        <Bone width="88%" height={12} />
        <Bone width="63%" height={12} />
      </View>

      <View style={styles.mediaSection}>
        {showLargeMedia ? (
          <View style={styles.mediaGrid}>
            <Bone width={96} height={96} radius={12} />
            <Bone width={96} height={96} radius={12} />
            <Bone width={96} height={96} radius={12} />
          </View>
        ) : (
          <Bone width="64%" height={74} radius={12} />
        )}
      </View>

      <View style={styles.statusRow}>
        <Bone width={62} height={22} radius={11} />
        <Bone width={74} height={22} radius={11} />
      </View>

      <View style={styles.detailCard}>
        <Bone width="72%" height={11} />
        <Bone width="90%" height={11} />
      </View>

      <View style={styles.footer}>
        <Bone width="36%" height={10} />
        <Bone width="24%" height={10} />
      </View>
    </View>
  );
});

export const FeedListSkeleton = memo(function FeedListSkeletonInner({
  count = DEFAULT_INITIAL_SKELETON_COUNT,
}: {
  count?: number;
}) {
  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={styles.listContent}
      scrollEnabled={false}
      showsVerticalScrollIndicator={false}>
      {Array.from({length: count}, (_, index) => (
        <FeedItemSkeleton key={`feed-skeleton-${index}`} />
      ))}
    </ScrollView>
  );
});

export const FeedListFooterSkeleton = memo(function FeedListFooterSkeletonInner({
  count = DEFAULT_APPEND_SKELETON_COUNT,
}: {
  count?: number;
}) {
  return (
    <View style={styles.footerList}>
      {Array.from({length: count}, (_, index) => (
        <FeedItemSkeleton
          key={`feed-footer-skeleton-${index}`}
          variant="append"
        />
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  flex: {
    flex: 1,
  },
  listContent: {
    paddingBottom: 24,
    gap: 10,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 14,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
    gap: 10,
  },
  bone: {
    backgroundColor: '#E2E8F0',
    opacity: 0.95,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  headerContent: {
    flex: 1,
    gap: 6,
  },
  textBlock: {
    gap: 8,
  },
  mediaSection: {
    alignItems: 'flex-start',
  },
  mediaGrid: {
    flexDirection: 'row',
    gap: 6,
  },
  statusRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  detailCard: {
    borderRadius: 12,
    backgroundColor: '#F8FAFC',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
    padding: 10,
    gap: 8,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
  },
  footerList: {
    gap: 10,
    paddingTop: 2,
    paddingBottom: 12,
  },
});
