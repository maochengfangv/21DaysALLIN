import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

export function Header({
  title,
  goBack,
}: {
  title: string;
  goBack: () => void;
}) {
  return (
    <View style={styles.header}>
      <Pressable onPress={goBack} style={styles.backButton}>
        <Text style={styles.backText}>返回</Text>
      </Pressable>
      <Text style={styles.headerTitle}>{title}</Text>
      <View style={styles.backPlaceholder} />
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    height: 100,
    backgroundColor: '#fff',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E2E8F0',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  backButton: {
    top: 20,
    paddingVertical: 12,
    paddingLeft: 12,
  },
  backText: {
    fontSize: 14,
    color: '#2563EB',
    fontWeight: '600',
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#0F172A',
  },
  backPlaceholder: {
    width: 36,
  },
});
