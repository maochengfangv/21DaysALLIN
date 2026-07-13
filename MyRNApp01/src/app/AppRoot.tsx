import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { BackHandler, Platform, StyleSheet, View } from 'react-native';
import { ImagePreviewProvider } from '../services/imagePreviewService';
import { Screens } from '../pages/index';
import type { RouteKey } from '../types/demo';
import { getErrorMessage } from '../utils/error';
import { logger } from '../utils/logger';

type ErrorUtilsShape = {
  getGlobalHandler?: () => (error: Error, isFatal?: boolean) => void;
  setGlobalHandler?: (
    handler: (error: Error, isFatal?: boolean) => void,
  ) => void;
};

export function AppRoot() {
  const [stack, setStack] = useState<RouteKey[]>(['home']);
  const [lastGlobalError, setLastGlobalError] = useState<string | null>(null);

  useEffect(() => {
    const errorUtils = (
      globalThis as typeof globalThis & { ErrorUtils?: ErrorUtilsShape }
    ).ErrorUtils;
    const previousHandler = errorUtils?.getGlobalHandler?.();

    errorUtils?.setGlobalHandler?.((error, isFatal) => {
      const message = `${isFatal ? 'Fatal' : 'Non-Fatal'}: ${getErrorMessage(
        error,
      )}`;
      logger.error('GlobalError', message);
      setLastGlobalError(message);
      previousHandler?.(error, isFatal);
    });
  }, []);

  const route = stack[stack.length - 1];
  const Screen = useMemo(() => Screens[route], [route]);

  useEffect(() => {
    logger.warn('AppRoot render', { route, stack });
  }, [route, stack]);

  const goBack = useCallback(() => {
    globalThis.console?.warn?.('AppRoot goBack pressed');
    setStack(prev => {
      globalThis.console?.warn?.('AppRoot goBack stack before update', prev);

      if (prev.length > 1) {
        const next = prev.slice(0, -1);
        logger.warn('AppRoot goBack pop', { prev, next });
        return next;
      }
      if (prev[0] !== 'home') {
        const next: RouteKey[] = ['home'];
        logger.warn('AppRoot goBack fallback home', { prev, next });
        return next;
      }

      logger.warn('AppRoot goBack noop at home', { prev });
      return prev;
    });
  }, []);

  useEffect(() => {
    if (Platform.OS !== 'android') {
      return;
    }

    const subscription = BackHandler.addEventListener(
      'hardwareBackPress',
      () => {
        if (stack.length > 1 || route !== 'home') {
          goBack();
          return true;
        }
        return false;
      },
    );

    return () => subscription.remove();
  }, [goBack, route, stack.length]);

  return (
    <ImagePreviewProvider>
      <View style={styles.container}>
        <Screen
          navigate={(nextRoute: RouteKey) =>
            setStack(prev => [...prev, nextRoute])
          }
          goBack={goBack}
          lastGlobalError={lastGlobalError}
          clearGlobalError={() => setLastGlobalError(null)}
        />
      </View>
    </ImagePreviewProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
