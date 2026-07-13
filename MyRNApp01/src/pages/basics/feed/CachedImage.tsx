import React, { memo, useCallback, useEffect, useMemo, useState } from 'react';
import {
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
  type ImageResizeMode,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import type { FeedImageCacheSource } from './types';

type CachedImageProps = {
  uri: string;
  style: StyleProp<ViewStyle>;
  resizeMode?: ImageResizeMode;
  onPress?: () => void;
  overlay?: React.ReactNode;
  showCacheBadge?: boolean;
};

const cacheRegistry = new Map<string, FeedImageCacheSource>();
const prefetchRegistry = new Map<string, Promise<void>>();

function normalizeCacheSource(value?: string): FeedImageCacheSource {
  if (value === 'memory' || value === 'disk' || value === 'disk/memory') {
    return value;
  }
  return 'unknown';
}

function getKnownCacheSource(uri: string) {
  return cacheRegistry.get(uri);
}

async function resolveQueryCache(uri: string) {
  if (!Image.queryCache) {
    return 'unknown';
  }

  const result = await Image.queryCache([uri]);
  const cacheSource = normalizeCacheSource(result[uri]);

  if (cacheSource !== 'unknown') {
    cacheRegistry.set(uri, cacheSource);
  }

  return cacheSource;
}

async function warmImageCache(uri: string) {
  if (!uri || cacheRegistry.has(uri) || prefetchRegistry.has(uri)) {
    return;
  }

  const prefetchTask = Image.prefetch(uri)
    .then(async success => {
      if (!success) {
        return;
      }

      const cacheSource = await resolveQueryCache(uri);
      cacheRegistry.set(uri, cacheSource === 'unknown' ? 'prefetch' : cacheSource);
    })
    .catch(() => undefined)
    .finally(() => {
      prefetchRegistry.delete(uri);
    });

  prefetchRegistry.set(uri, prefetchTask);
}

export function prefetchFeedImages(uris: string[]) {
  const uniqueUris = Array.from(new Set(uris.filter(Boolean)));
  uniqueUris.forEach(uri => {
    warmImageCache(uri).catch(() => undefined);
  });
}

function getCacheLabel(source: FeedImageCacheSource) {
  switch (source) {
    case 'memory':
      return 'MEM';
    case 'disk':
      return 'DISK';
    case 'disk/memory':
      return 'MEM+DISK';
    case 'prefetch':
      return 'PREFETCH';
    case 'http':
      return 'HTTP';
    case 'error':
      return 'ERROR';
    default:
      return 'MISS';
  }
}

function CachedImageInner({
  uri,
  style,
  resizeMode = 'cover',
  onPress,
  overlay,
  showCacheBadge = true,
}: CachedImageProps) {
  const knownCacheSource = useMemo(() => getKnownCacheSource(uri), [uri]);
  const [loadState, setLoadState] = useState<'loading' | 'success' | 'error'>(
    knownCacheSource && knownCacheSource !== 'error' ? 'success' : 'loading',
  );
  const [cacheSource, setCacheSource] = useState<FeedImageCacheSource>(
    knownCacheSource ?? 'unknown',
  );
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const nextKnownSource = getKnownCacheSource(uri);

    setLoadState(
      nextKnownSource && nextKnownSource !== 'error' ? 'success' : 'loading',
    );
    setCacheSource(nextKnownSource ?? 'unknown');

    warmImageCache(uri).catch(() => undefined);
    resolveQueryCache(uri)
      .then(nextCacheSource => {
        if (cancelled || nextCacheSource === 'unknown') {
          return;
        }

        setCacheSource(nextCacheSource);
        setLoadState(prevState => (prevState === 'error' ? prevState : 'success'));
      })
      .catch(() => undefined);

    return () => {
      cancelled = true;
    };
  }, [uri, reloadKey]);

  const onLoadStart = useCallback(() => {
    if (!getKnownCacheSource(uri)) {
      setLoadState('loading');
    }
  }, [uri]);

  const onLoad = useCallback(() => {
    resolveQueryCache(uri).then(nextCacheSource => {
      const resolvedSource =
        nextCacheSource === 'unknown' ? 'http' : nextCacheSource;
      cacheRegistry.set(uri, resolvedSource);
      setCacheSource(resolvedSource);
      setLoadState('success');
    }).catch(() => undefined);
  }, [uri]);

  const onError = useCallback(() => {
    cacheRegistry.set(uri, 'error');
    setCacheSource('error');
    setLoadState('error');
  }, [uri]);

  const retryLoad = useCallback(() => {
    cacheRegistry.delete(uri);
    setCacheSource('unknown');
    setLoadState('loading');
    setReloadKey(value => value + 1);
  }, [uri]);

  const badgeLabel = useMemo(() => getCacheLabel(cacheSource), [cacheSource]);
  const canPressImage = !!onPress && loadState !== 'error';

  const content = (
    <View style={[styles.frame, style]}>
      <Image
        key={`${uri}-${reloadKey}`}
        source={{
          uri,
          cache: 'force-cache',
        }}
        resizeMode={resizeMode}
        style={StyleSheet.absoluteFill}
        onLoadStart={onLoadStart}
        onLoad={onLoad}
        onError={onError}
      />

      {loadState === 'loading' ? (
        <View style={styles.loadingOverlay}>
          <View style={styles.skeletonBlock} />
          <Text style={styles.loadingText}>缓存预热中...</Text>
        </View>
      ) : null}

      {loadState === 'error' ? (
        <Pressable onPress={retryLoad} style={styles.errorOverlay}>
          <Text style={styles.errorTitle}>加载失败</Text>
          <Text style={styles.errorText}>点击重试</Text>
        </Pressable>
      ) : null}

      {overlay}

      {showCacheBadge ? (
        <View style={styles.badge}>
          <Text style={styles.badgeText}>{badgeLabel}</Text>
        </View>
      ) : null}
    </View>
  );

  if (canPressImage) {
    return (
      <Pressable onPress={onPress} style={styles.pressable}>
        {content}
      </Pressable>
    );
  }

  return content;
}

export const CachedImage = memo(
  CachedImageInner,
  (prevProps, nextProps) =>
    prevProps.uri === nextProps.uri &&
    prevProps.style === nextProps.style &&
    prevProps.resizeMode === nextProps.resizeMode &&
    prevProps.onPress === nextProps.onPress &&
    prevProps.overlay === nextProps.overlay &&
    prevProps.showCacheBadge === nextProps.showCacheBadge,
);

const styles = StyleSheet.create({
  pressable: {
    borderRadius: 12,
  },
  frame: {
    overflow: 'hidden',
    borderRadius: 12,
    backgroundColor: '#E2E8F0',
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#E2E8F0',
  },
  skeletonBlock: {
    width: '100%',
    height: '100%',
    backgroundColor: '#CBD5E1',
    opacity: 0.45,
  },
  loadingText: {
    position: 'absolute',
    fontSize: 11,
    color: '#475569',
    fontWeight: '600',
  },
  errorOverlay: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#E2E8F0',
    gap: 4,
    paddingHorizontal: 8,
  },
  errorTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: '#B91C1C',
  },
  errorText: {
    fontSize: 11,
    color: '#7F1D1D',
  },
  badge: {
    position: 'absolute',
    left: 6,
    bottom: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(15, 23, 42, 0.70)',
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  badgeText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#FFFFFF',
  },
});
