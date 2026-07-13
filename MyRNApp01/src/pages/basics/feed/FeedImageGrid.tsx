import React, { memo, useEffect, useMemo, useState } from 'react';
import { Dimensions, Pressable, StyleSheet, Text, View } from 'react-native';
import { CachedImage, prefetchFeedImages } from './CachedImage';

const SCREEN_WIDTH = Dimensions.get('window').width;
const ITEM_HORIZONTAL_PADDING = 24;
const GRID_GAP = 6;
const PREVIEW_IMAGE_LIMIT = 9;
const GRID_MAX_WIDTH = SCREEN_WIDTH - 32 - ITEM_HORIZONTAL_PADDING;
const SINGLE_IMAGE_WIDTH = Math.min(Math.round(GRID_MAX_WIDTH * 0.72), 220);
const SINGLE_IMAGE_HEIGHT = Math.round(SINGLE_IMAGE_WIDTH * 0.76);
const DOUBLE_IMAGE_SIZE = Math.floor((GRID_MAX_WIDTH - GRID_GAP) / 2);
const TRIPLE_IMAGE_SIZE = Math.floor((GRID_MAX_WIDTH - GRID_GAP * 2) / 3);

type LayoutCell = {
  key: string;
  uri: string;
  index: number;
  width: number;
  height: number;
  showMoreOverlay: boolean;
};

type LayoutRow = {
  key: string;
  cells: LayoutCell[];
};

function getWechatLikeRowPattern(count: number) {
  switch (count) {
    case 1:
      return [1];
    case 2:
      return [2];
    case 3:
      return [3];
    case 4:
      return [2, 2];
    case 5:
      return [3, 2];
    case 6:
      return [3, 3];
    case 7:
      return [3, 3, 1];
    case 8:
      return [3, 3, 2];
    case 9:
      return [3, 3, 3];
    default: {
      const rows: number[] = [];
      let remaining = count;
      while (remaining > 0) {
        rows.push(Math.min(3, remaining));
        remaining -= 3;
      }
      return rows;
    }
  }
}

function getCellSize(rowCount: number, totalVisibleCount: number) {
  if (totalVisibleCount === 1) {
    return {
      width: SINGLE_IMAGE_WIDTH,
      height: SINGLE_IMAGE_HEIGHT,
    };
  }

  if (rowCount === 2 && totalVisibleCount <= 4) {
    return {
      width: DOUBLE_IMAGE_SIZE,
      height: DOUBLE_IMAGE_SIZE,
    };
  }

  return {
    width: TRIPLE_IMAGE_SIZE,
    height: TRIPLE_IMAGE_SIZE,
  };
}

function getVisibleImagesLayout(
  visibleImages: string[],
  totalCount: number,
  expanded: boolean,
) {
  const rowPattern = getWechatLikeRowPattern(visibleImages.length);
  let cursor = 0;

  return rowPattern.map((rowCount, rowIndex) => {
    const cellSize = getCellSize(rowCount, visibleImages.length);
    const rowImages = visibleImages.slice(cursor, cursor + rowCount);
    cursor += rowCount;

    return {
      key: `row-${rowIndex}-${rowCount}`,
      cells: rowImages.map((uri, cellIndex) => {
        const absoluteIndex = cursor - rowCount + cellIndex;
        const isLastPreviewImage =
          !expanded &&
          totalCount > PREVIEW_IMAGE_LIMIT &&
          absoluteIndex === PREVIEW_IMAGE_LIMIT - 1;

        return {
          key: uri,
          uri,
          index: absoluteIndex,
          width: cellSize.width,
          height: cellSize.height,
          showMoreOverlay: isLastPreviewImage,
        };
      }),
    } satisfies LayoutRow;
  });
}

function FeedImageGridInner({
  images,
  shouldRenderImages,
  onPressImage,
}: {
  images: string[];
  shouldRenderImages: boolean;
  onPressImage?: (index: number) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const hasCollapsedImages = images.length > PREVIEW_IMAGE_LIMIT;
  const visibleImages = useMemo(() => {
    if (expanded || !hasCollapsedImages) {
      return images;
    }
    return images.slice(0, PREVIEW_IMAGE_LIMIT);
  }, [expanded, hasCollapsedImages, images]);

  const layoutRows = useMemo(() => {
    return getVisibleImagesLayout(visibleImages, images.length, expanded);
  }, [expanded, images.length, visibleImages]);
  const hiddenCount = images.length - PREVIEW_IMAGE_LIMIT;

  useEffect(() => {
    if (!shouldRenderImages) {
      return;
    }

    prefetchFeedImages(images);
  }, [images, shouldRenderImages]);

  if (!shouldRenderImages) {
    return (
      <View style={styles.placeholder}>
        <Text style={styles.placeholderTitle}>{images.length} 张图片</Text>
        <Text style={styles.placeholderText}>
          进入可视区域后再挂载朋友圈图组，优先保证首屏和滚动稳定。
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.grid}>
        {layoutRows.map(row => (
          <View key={row.key} style={styles.row}>
            {row.cells.map(cell => {
              const imageStyle = {
                width: cell.width,
                height: cell.height,
              };
              const pressImage = () => {
                onPressImage?.(cell.index);
              };

              return (
                <CachedImage
                  key={cell.key}
                  uri={cell.uri}
                  style={imageStyle}
                  onPress={pressImage}
                  overlay={
                    cell.showMoreOverlay ? (
                      <View style={styles.moreOverlay}>
                        <Text style={styles.moreOverlayText}>+{hiddenCount}</Text>
                      </View>
                    ) : undefined
                  }
                />
              );
            })}
          </View>
        ))}
      </View>

      {hasCollapsedImages ? (
        <Pressable
          onPress={() => setExpanded(value => !value)}
          style={styles.expandButton}>
          <Text style={styles.expandText}>
            {expanded
              ? '收起多余图片'
              : `展开剩余 ${hiddenCount} 张图片`}
          </Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export const FeedImageGrid = memo(
  FeedImageGridInner,
  (prevProps, nextProps) =>
    prevProps.images === nextProps.images &&
    prevProps.shouldRenderImages === nextProps.shouldRenderImages &&
    prevProps.onPressImage === nextProps.onPressImage,
);

const styles = StyleSheet.create({
  container: {
    gap: 8,
    marginTop: 10,
  },
  grid: {
    gap: GRID_GAP,
    alignItems: 'flex-start',
  },
  row: {
    flexDirection: 'row',
    gap: GRID_GAP,
  },
  moreOverlay: {
    ...StyleSheet.absoluteFill,
    borderRadius: 12,
    backgroundColor: 'rgba(15, 23, 42, 0.38)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  moreOverlayText: {
    fontSize: 22,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  placeholder: {
    marginTop: 10,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#EEF2FF',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#C7D2FE',
  },
  placeholderTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: '#4338CA',
  },
  placeholderText: {
    marginTop: 4,
    fontSize: 12,
    lineHeight: 18,
    color: '#4F46E5',
  },
  expandButton: {
    alignSelf: 'flex-start',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
    backgroundColor: '#EFF6FF',
  },
  expandText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#2563EB',
  },
});
