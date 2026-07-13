import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Dimensions,
  FlatList,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
  type ListRenderItemInfo,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from 'react-native';
import { Image } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const SCREEN_WIDTH = Dimensions.get('window').width;
const SCREEN_HEIGHT = Dimensions.get('window').height;

type ImagePreviewModalProps = {
  visible: boolean;
  images: string[];
  initialIndex: number;
  onClose: () => void;
};

export function ImagePreviewModal({
  visible,
  images,
  initialIndex,
  onClose,
}: ImagePreviewModalProps) {
  const insets = useSafeAreaInsets();
  const flatListRef = useRef<FlatList<string>>(null);
  const safeInitialIndex = useMemo(() => {
    if (images.length === 0) {
      return 0;
    }
    return Math.min(Math.max(initialIndex, 0), images.length - 1);
  }, [images.length, initialIndex]);
  const [currentIndex, setCurrentIndex] = useState(safeInitialIndex);

  useEffect(() => {
    if (!visible) {
      return;
    }

    setCurrentIndex(safeInitialIndex);

    requestAnimationFrame(() => {
      flatListRef.current?.scrollToOffset({
        offset: safeInitialIndex * SCREEN_WIDTH,
        animated: false,
      });
    });
  }, [safeInitialIndex, visible]);

  const keyExtractor = useCallback((item: string) => item, []);

  const renderItem = useCallback(
    ({ item }: ListRenderItemInfo<string>) => {
      return (
        <View style={styles.slide}>
          <Image
            source={{ uri: item }}
            resizeMode="contain"
            style={styles.previewImage}
          />
        </View>
      );
    },
    [],
  );

  const onMomentumScrollEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const offsetX = event.nativeEvent.contentOffset.x;
      const nextIndex = Math.round(offsetX / SCREEN_WIDTH);
      setCurrentIndex(nextIndex);
    },
    [],
  );

  if (!visible || images.length === 0) {
    return null;
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={[styles.topBar, { paddingTop: insets.top + 8 }]}>
          <Text style={styles.pageIndicator}>
            {currentIndex + 1} / {images.length}
          </Text>
          <Pressable onPress={onClose} style={styles.closeButton}>
            <Text style={styles.closeText}>关闭</Text>
          </Pressable>
        </View>

        <FlatList
          ref={flatListRef}
          data={images}
          keyExtractor={keyExtractor}
          renderItem={renderItem}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          initialScrollIndex={safeInitialIndex}
          getItemLayout={(_, index) => ({
            length: SCREEN_WIDTH,
            offset: SCREEN_WIDTH * index,
            index,
          })}
          onMomentumScrollEnd={onMomentumScrollEnd}
          windowSize={2}
          initialNumToRender={1}
          maxToRenderPerBatch={1}
        />
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.94)',
  },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 10,
  },
  pageIndicator: {
    fontSize: 15,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  closeButton: {
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: 'rgba(255, 255, 255, 0.14)',
  },
  closeText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  slide: {
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT - 80,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    paddingBottom: 24,
  },
  previewImage: {
    width: '100%',
    height: '100%',
  },
});
