import React, { useEffect, useMemo, useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  Image,
  TouchableOpacity,
  Platform,
} from 'react-native';
import type {
  BusinessCardData,
  CardAction,
  CardActionType,
} from './types';

let BusinessCardFabricView: any = null;

try {
  BusinessCardFabricView =
    require('../../../specs/NativeBusinessCardView').default;
} catch (_) {
  BusinessCardFabricView = null;
}

interface Props {
  data: BusinessCardData;
  actions?: CardAction[];
  onPress?: (cardId: string) => void;
  onActionPress?: (
    cardId: string,
    actionId: string,
    actionType: CardActionType,
  ) => void;
  onExposure?: (cardId: string, timestamp: number) => void;
  theme?: 'light' | 'dark';
}

export const BusinessCard: React.FC<Props> = ({
  data,
  actions,
  onPress,
  onActionPress,
  onExposure,
  theme = 'light',
}) => {
  const [exposed, setExposed] = useState(false);

  useEffect(() => {
    if (exposed) return;
    const timer = setTimeout(() => {
      setExposed(true);
      onExposure?.(data.cardId, Date.now());
    }, 300);
    return () => clearTimeout(timer);
  }, [data.cardId, exposed, onExposure]);

  const cardDataJson = useMemo(() => JSON.stringify(data), [data]);
  const actionsJson = useMemo(
    () => (actions ? JSON.stringify(actions) : undefined),
    [actions],
  );

  if (
    Platform.OS === 'ios' &&
    BusinessCardFabricView &&
    data.cardType === 0
  ) {
    return (
      <BusinessCardFabricView
        style={styles.fabricWrapper}
        cardData={cardDataJson}
        actions={actionsJson}
        cardType={data.cardType}
        cornerRadius={16}
        enableShadow={true}
        onCardPress={(event: any) => {
          const cardId = event?.nativeEvent?.cardId ?? data.cardId;
          onPress?.(cardId);
        }}
        onActionPress={(event: any) => {
          const native = event?.nativeEvent ?? {};
          onActionPress?.(
            native.cardId ?? data.cardId,
            native.actionId ?? '',
            (native.actionType ?? 0) as CardActionType,
          );
        }}
        onExposure={(event: any) => {
          const native = event?.nativeEvent ?? {};
          onExposure?.(
            native.cardId ?? data.cardId,
            native.timestamp ?? Date.now(),
          );
        }}
      />
    );
  }

  return (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={() => onPress?.(data.cardId)}
      style={[
        styles.card,
        theme === 'dark' ? styles.cardDark : styles.cardLight,
      ]}>
      {data.coverUrl ? (
        <View style={styles.coverContainer}>
          <Image source={{ uri: data.coverUrl }} style={styles.cover} />
          {data.tag ? (
            <View style={styles.tagChip}>
              <Text style={styles.tagText}>{data.tag}</Text>
            </View>
          ) : null}
        </View>
      ) : null}

      <View style={styles.infoArea}>
        <Text
          style={[
            styles.title,
            theme === 'dark' ? styles.textLight : styles.textDark,
          ]}
          numberOfLines={2}>
          {data.title}
        </Text>
        {data.subtitle ? (
          <Text style={styles.subtitle} numberOfLines={1}>
            {data.subtitle}
          </Text>
        ) : null}
        {data.description ? (
          <Text style={styles.desc} numberOfLines={2}>
            {data.description}
          </Text>
        ) : null}
        <View style={styles.metaRow}>
          {data.author ? (
            <Text style={styles.author}>👤 {data.author}</Text>
          ) : null}
          <View style={{ flex: 1 }} />
          {data.timestamp ? (
            <Text style={styles.time}>⏱ {formatTime(data.timestamp)}</Text>
          ) : null}
        </View>
      </View>

      {actions && actions.length > 0 ? (
        <View style={styles.actionBar}>
          {actions.map((action, idx) => (
            <TouchableOpacity
              key={action.id}
              activeOpacity={0.75}
              onPress={() =>
                onActionPress?.(data.cardId, action.id, action.actionType)
              }
              style={[
                styles.actionBtn,
                idx === 0 ? styles.actionPrimary : styles.actionSecondary,
              ]}>
              <Text
                style={[
                  styles.actionText,
                  idx === 0
                    ? styles.actionTextPrimary
                    : styles.actionTextSecondary,
                ]}>
                {action.title}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      ) : null}
    </TouchableOpacity>
  );
};

function formatTime(ts: number): string {
  const diff = (Date.now() - ts) / 1000;
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)}天前`;
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const styles = StyleSheet.create({
  fabricWrapper: {
    marginHorizontal: 16,
    marginBottom: 16,
  },
  card: {
    marginHorizontal: 16,
    marginBottom: 16,
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowOffset: { width: 0, height: 4 },
    shadowRadius: 12,
    elevation: 3,
  },
  cardLight: {
    backgroundColor: '#FFFFFF',
  },
  cardDark: {
    backgroundColor: '#1C1C1E',
  },
  coverContainer: {
    width: '100%',
    position: 'relative',
  },
  cover: {
    width: '100%',
    aspectRatio: 16 / 9,
    backgroundColor: '#E5E5EA',
  },
  tagChip: {
    position: 'absolute',
    top: 12,
    left: 12,
    paddingHorizontal: 12,
    height: 24,
    borderRadius: 999,
    backgroundColor: 'rgba(79, 70, 229, 0.12)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  tagText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#4F46E5',
  },
  infoArea: {
    padding: 16,
  },
  title: {
    fontSize: 17,
    fontWeight: '700',
    lineHeight: 24,
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    fontWeight: '500',
    color: '#475569',
    marginBottom: 6,
  },
  desc: {
    fontSize: 13,
    color: '#64748B',
    lineHeight: 20,
    marginBottom: 8,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  author: {
    fontSize: 12,
    fontWeight: '600',
    color: '#2563EB',
  },
  time: {
    fontSize: 12,
    color: '#94A3B8',
  },
  textLight: {
    color: '#F8FAFC',
  },
  textDark: {
    color: '#0F172A',
  },
  actionBar: {
    flexDirection: 'row',
    gap: 10,
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  actionBtn: {
    flex: 1,
    height: 40,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  actionPrimary: {
    backgroundColor: '#007AFF',
  },
  actionSecondary: {
    backgroundColor: '#F1F5F9',
  },
  actionText: {
    fontSize: 14,
    fontWeight: '600',
  },
  actionTextPrimary: {
    color: '#FFFFFF',
  },
  actionTextSecondary: {
    color: '#334155',
  },
});

export default BusinessCard;
