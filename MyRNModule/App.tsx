import React, { Component, useCallback, useEffect, useState } from 'react';
import {
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  useColorScheme,
  View,
} from 'react-native';
import { businessDataHandler } from './src/services/business/BusinessDataHandler';
import {
  CALLBACK_IDS,
  type CallbackId,
  type ScenePayloadMap,
} from './src/shared/businessConstants';

let HotUpdateManager: React.ComponentType<any> | null = null;
let HotUpdateService: any = null;

try {
  HotUpdateManager = require('./src/components/HotUpdateManager').default;
  HotUpdateService = require('./src/services/hot-update/HotUpdateService').default;
} catch (error) {
  console.warn('[App] 热更新模块加载失败，热更新功能不可用:', error);
}

class ErrorBoundary extends Component<
  { children: React.ReactNode; name: string },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: React.ReactNode; name: string }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return (
        <View style={styles.errorBox}>
          <Text style={styles.errorTitle}>{this.props.name} 加载失败</Text>
          <Text style={styles.errorMsg}>{this.state.error?.message}</Text>
        </View>
      );
    }

    return this.props.children;
  }
}

let NativeCounter: any = null;
let NativeColoredView: any = null;

try {
  NativeCounter = require('./specs/NativeCounter').default;
} catch (_) {
  NativeCounter = null;
}

try {
  NativeColoredView = require('./specs/NativeColoredView').default;
} catch (_) {
  NativeColoredView = null;
}

type BusinessLogItem = {
  callbackId: CallbackId;
  payload: ScenePayloadMap[CallbackId];
};

const SCENE_TITLES: Record<CallbackId, string> = {
  [CALLBACK_IDS.SCENE_A]: '场景 A',
  [CALLBACK_IDS.SCENE_B]: '场景 B',
  [CALLBACK_IDS.SCENE_C]: '场景 C',
};

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  useEffect(() => {
    let mounted = true;

    const bootstrapHotUpdate = async () => {
      if (!HotUpdateService) {
        return;
      }

      try {
        await HotUpdateService.initialize();
        if (!mounted) {
          return;
        }
        await HotUpdateService.markApplicationReady();
        await HotUpdateService.autoCheckForUpdate();
      } catch (error) {
        console.error('[HotUpdate]', error);
      }
    };

    bootstrapHotUpdate();

    return () => {
      mounted = false;
    };
  }, []);

  return (
    <View style={[styles.container, { paddingTop: 60 }]}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <Text style={styles.title}>TurboModule + Native Event + Fabric Demo</Text>
      {HotUpdateManager ? <HotUpdateManager /> : null}
      <ErrorBoundary name="TurboModule">
        <CounterDemo />
      </ErrorBoundary>
      <ErrorBoundary name="Native Event">
        <BusinessDataDemo />
      </ErrorBoundary>
      <ErrorBoundary name="Fabric Component">
        <FabricDemo />
      </ErrorBoundary>
    </View>
  );
}

function CounterDemo() {
  const [count, setCount] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    if (!NativeCounter) {
      return;
    }

    const value = await NativeCounter.getValue();
    setCount(value);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!NativeCounter) {
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>TurboModule: NativeCounter</Text>
        <Text style={styles.notReady}>
          原生模块未注册，请先在 `IOSRNContainer` 中编译运行。
        </Text>
      </View>
    );
  }

  const handleIncrement = async () => {
    const value = await NativeCounter.increment(1);
    setCount(value);
  };

  const handleDecrement = async () => {
    const value = await NativeCounter.decrement(1);
    setCount(value);
  };

  const handleReset = async () => {
    await NativeCounter.reset();
    setCount(0);
  };

  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>TurboModule: NativeCounter</Text>
      <Text style={styles.counterValue}>{count ?? '...'}</Text>
      <View style={styles.buttonRow}>
        <TouchableOpacity style={styles.btn} onPress={handleIncrement}>
          <Text style={styles.btnText}>+1</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.btn} onPress={handleDecrement}>
          <Text style={styles.btnText}>-1</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.btn, styles.btnReset]}
          onPress={handleReset}>
          <Text style={styles.btnText}>Reset</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function BusinessDataDemo() {
  const [logs, setLogs] = useState<BusinessLogItem[]>([]);

  useEffect(() => {
    const cleanups = [
      businessDataHandler.register(CALLBACK_IDS.SCENE_A, payload => {
        setLogs(prev => [
          { callbackId: CALLBACK_IDS.SCENE_A, payload },
          ...prev.slice(0, 4),
        ]);
      }),
      businessDataHandler.register(CALLBACK_IDS.SCENE_B, payload => {
        setLogs(prev => [
          { callbackId: CALLBACK_IDS.SCENE_B, payload },
          ...prev.slice(0, 4),
        ]);
      }),
      businessDataHandler.register(CALLBACK_IDS.SCENE_C, payload => {
        setLogs(prev => [
          { callbackId: CALLBACK_IDS.SCENE_C, payload },
          ...prev.slice(0, 4),
        ]);
      }),
    ];

    businessDataHandler.startListening();

    return () => {
      cleanups.forEach(cleanup => cleanup());
      businessDataHandler.stopListening();
      businessDataHandler.clear();
    };
  }, []);

  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Native Event: BusinessData</Text>
      <Text style={styles.hintSmall}>
        固定 event name，通过 callbackId 路由多业务场景
      </Text>
      {logs.length === 0 ? (
        <Text style={styles.notReady}>
          点击原生页面右上角的「场景A / 场景B / 场景C」按钮触发数据推送
        </Text>
      ) : (
        logs.map((item, index) => (
          <View key={`${item.callbackId}-${index}`} style={styles.eventCard}>
            <Text style={styles.eventTitle}>
              {SCENE_TITLES[item.callbackId]} / {item.callbackId}
            </Text>
            <Text style={styles.eventPayload}>
              {JSON.stringify(item.payload)}
            </Text>
          </View>
        ))
      )}
    </View>
  );
}

function FabricDemo() {
  const [liveValue, setLiveValue] = useState(0);
  const [isActive, setIsActive] = useState(false);

  if (!NativeColoredView) {
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Fabric Component: NativeColoredView</Text>
        <Text style={styles.notReady}>Fabric Component 未注册</Text>
      </View>
    );
  }

  const ColoredView = NativeColoredView;

  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Fabric Component: NativeColoredView</Text>
      <ColoredView
        style={styles.fabricBox}
        color="#4F46E5"
        cornerRadius={16}
        isActive={isActive}
        onValueChange={(event: { nativeEvent: { value?: number } }) => {
          setLiveValue(event.nativeEvent.value ?? 0);
        }}
      />
      <TouchableOpacity
        style={[styles.btn, styles.singleButton]}
        onPress={() => setIsActive(prev => !prev)}>
        <Text style={styles.btnText}>{isActive ? '停止推送' : '开始推送'}</Text>
      </TouchableOpacity>
      <Text style={styles.liveValueText}>当前原生值: {liveValue}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
    paddingVertical: 16,
    color: '#333',
  },
  section: {
    marginHorizontal: 16,
    marginBottom: 20,
    padding: 16,
    backgroundColor: '#FFF',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowOffset: { width: 0, height: 2 },
    shadowRadius: 8,
    elevation: 2,
    alignItems: 'center',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#555',
    marginBottom: 12,
  },
  counterValue: {
    fontSize: 48,
    fontWeight: '800',
    color: '#333',
    marginBottom: 16,
  },
  notReady: {
    fontSize: 14,
    color: '#FF9500',
    textAlign: 'center',
    lineHeight: 20,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 10,
  },
  btn: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    backgroundColor: '#007AFF',
    borderRadius: 8,
  },
  btnReset: {
    backgroundColor: '#FF3B30',
  },
  btnText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '600',
  },
  singleButton: {
    marginBottom: 12,
  },
  fabricBox: {
    width: 120,
    height: 120,
    marginBottom: 12,
  },
  liveValueText: {
    fontSize: 28,
    fontWeight: '700',
    color: '#4F46E5',
    marginTop: 4,
  },
  hintSmall: {
    fontSize: 12,
    color: '#666',
    marginBottom: 10,
    textAlign: 'center',
  },
  eventCard: {
    width: '100%',
    marginTop: 8,
    padding: 12,
    borderRadius: 10,
    backgroundColor: '#F4F7FF',
  },
  eventTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 6,
  },
  eventPayload: {
    fontSize: 12,
    color: '#475569',
  },
  errorBox: {
    marginHorizontal: 16,
    marginBottom: 20,
    padding: 16,
    backgroundColor: '#FFF3F0',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#FF6B6B',
    alignItems: 'center',
  },
  errorTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#FF3B30',
    marginBottom: 8,
  },
  errorMsg: {
    fontSize: 13,
    color: '#8B0000',
    textAlign: 'center',
  },
});

export default App;
