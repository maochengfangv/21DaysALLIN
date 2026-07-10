import React from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';
import {SafeAreaView, type Edge} from 'react-native-safe-area-context';

export function Header({
  title,
  goBack,
  safeAreaMode = 'top',
  rightSlot,
}: {
  title: string;
  goBack: () => void;
  safeAreaMode?: 'top' | 'none';
  rightSlot?: React.ReactNode;
}) {
  const edges: readonly Edge[] = safeAreaMode === 'top' ? ['top'] : [];

  return (
    <SafeAreaView edges={edges} style={styles.safeArea}>
      <View style={styles.header}>
        <View style={styles.side}>
          <Pressable
            onPress={goBack}
            hitSlop={HIT_SLOP}
            style={styles.backButton}>
            <Text style={styles.backText}>返回</Text>
          </Pressable>
        </View>

        <View pointerEvents="none" style={styles.titleContainer}>
          <Text numberOfLines={1} style={styles.headerTitle}>
            {title}
          </Text>
        </View>

        <View style={styles.side}>{rightSlot}</View>
      </View>
    </SafeAreaView>
  );
}

const CONTENT_HEIGHT = 48;
const SIDE_WIDTH = 48;
const HIT_SLOP = {top: 8, bottom: 8, left: 8, right: 8};

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: '#fff',
  },
  header: {
    height: CONTENT_HEIGHT,
    backgroundColor: '#fff',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E2E8F0',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  side: {
    width: SIDE_WIDTH,
    height: '100%',
    justifyContent: 'center',
  },
  backButton: {
    minWidth: 44,
    minHeight: 44,
    justifyContent: 'center',
  },
  backText: {
    fontSize: 14,
    color: '#2563EB',
    fontWeight: '600',
  },
  titleContainer: {
    position: 'absolute',
    left: SIDE_WIDTH,
    right: SIDE_WIDTH,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0F172A',
  },
});
