import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

export function ScreenContainer({
  title,
  summary,
  points,
  children,
  scroll = true,
  style,
}: {
  title: string;
  summary: string;
  points: string[];
  children: React.ReactNode;
  scroll?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  const content = (
    <View style={[styles.container, style]}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.summary}>{summary}</Text>
      <View style={styles.points}>
        {points.map(point => (
          <Text key={point} style={styles.point}>
            {'\u2022'} {point}
          </Text>
        ))}
      </View>
      {children}
    </View>
  );

  if (!scroll) {
    return content;
  }

  return <ScrollView style={styles.flex}>{content}</ScrollView>;
}

export function ActionButton({
  title,
  onPress,
  variant = 'primary',
}: {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary';
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.button,
        variant === 'primary' ? styles.primary : styles.secondary,
      ]}>
      <Text
        style={[
          styles.buttonText,
          variant === 'primary' ? styles.primaryText : styles.secondaryText,
        ]}>
        {title}
      </Text>
    </Pressable>
  );
}

export function ResultCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>{title}</Text>
      {typeof children === 'string' ? (
        <Text style={styles.cardText}>{children}</Text>
      ) : (
        children
      )}
    </View>
  );
}

export function MetricPill({
  label,
  value,
}: {
  label: string;
  value: string | number;
}) {
  return (
    <View style={styles.metric}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

export const uiStyles = StyleSheet.create({
  row: {flexDirection: 'row', flexWrap: 'wrap', gap: 8},
  gap12: {gap: 12},
  gap16: {gap: 16},
  input: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#CBD5E1',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#fff',
    color: '#0F172A',
  },
  label: {fontSize: 13, color: '#475569', marginBottom: 6},
  error: {fontSize: 12, color: '#DC2626', marginTop: 4},
});

const styles = StyleSheet.create({
  flex: {flex: 1, backgroundColor: '#F8FAFC'},
  container: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 28,
    backgroundColor: '#F8FAFC',
    gap: 12,
  },
  title: {fontSize: 24, fontWeight: '700', color: '#0F172A'},
  summary: {fontSize: 14, lineHeight: 20, color: '#334155'},
  points: {gap: 4, marginBottom: 4},
  point: {fontSize: 13, lineHeight: 19, color: '#475569'},
  button: {
    minHeight: 42,
    borderRadius: 12,
    paddingHorizontal: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  primary: {backgroundColor: '#2563EB'},
  secondary: {backgroundColor: '#E2E8F0'},
  buttonText: {fontSize: 14, fontWeight: '600'},
  primaryText: {color: '#fff'},
  secondaryText: {color: '#0F172A'},
  card: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 14,
    gap: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#E2E8F0',
  },
  cardTitle: {fontSize: 16, fontWeight: '700', color: '#0F172A'},
  cardText: {fontSize: 13, lineHeight: 19, color: '#334155'},
  metric: {
    backgroundColor: '#E0F2FE',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
    flexDirection: 'row',
    gap: 6,
  },
  metricLabel: {fontSize: 12, color: '#0369A1'},
  metricValue: {fontSize: 12, fontWeight: '700', color: '#0C4A6E'},
});
