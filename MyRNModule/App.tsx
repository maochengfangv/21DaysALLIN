import React, { Component, useCallback, useEffect, useState } from 'react';
import {
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  useColorScheme,
  View,
} from 'react-native';

// ==================== 错误边界 ====================

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

// ==================== 安全导入 Native 模块 ====================

let NativeCounter: any = null;
let NativeColoredView: any = null;

try {
  NativeCounter = require('./specs/NativeCounter').default;
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
} catch (_) {
  // TurboModule 未注册，NativeCounter 保持 null
}

try {
  NativeColoredView = require('./specs/NativeColoredView').default;
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
} catch (_) {
  // Fabric Component 未注册
}

// ==================== 主入口 ====================

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <View style={[styles.container, { paddingTop: 60 }]}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <Text style={styles.title}>TurboModule + Fabric Demo</Text>
      <ErrorBoundary name="TurboModule">
        <CounterDemo />
      </ErrorBoundary>
      <ErrorBoundary name="Fabric Component">
        <FabricDemo />
      </ErrorBoundary>
    </View>
  );
}

// ==================== TurboModule: NativeCounter ====================

function CounterDemo() {
  const [count, setCount] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    if (!NativeCounter) { return; }
    const val = await NativeCounter.getValue();
    setCount(val);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!NativeCounter) {
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>TurboModule: NativeCounter</Text>
        <Text style={styles.notReady}>原生模块未注册，请在 IOSRNContainer 中完成 codegen 并编译</Text>
      </View>
    );
  }

  const handleIncrement = async () => {
    const val = await NativeCounter.increment(1);
    setCount(val);
  };

  const handleDecrement = async () => {
    const val = await NativeCounter.decrement(1);
    setCount(val);
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

// ==================== Fabric Component: NativeColoredView ====================

const COLORS = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7'];
const RADIUS = [0, 12, 24];

function FabricDemo() {
  const [colorIdx, setColorIdx] = useState(0);
  const [radiusIdx, setRadiusIdx] = useState(0);

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
        color={COLORS[colorIdx]}
        cornerRadius={RADIUS[radiusIdx]}
        style={styles.fabricBox}
      />

      <View style={styles.buttonRow}>
        <TouchableOpacity
          style={styles.btn}
          onPress={() => setColorIdx((colorIdx + 1) % COLORS.length)}>
          <Text style={styles.btnText}>换色</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.btn}
          onPress={() => setRadiusIdx((radiusIdx + 1) % RADIUS.length)}>
          <Text style={styles.btnText}>圆角: {RADIUS[radiusIdx]}</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.hint}>
        color={COLORS[colorIdx]}  cornerRadius={RADIUS[radiusIdx]}
      </Text>
    </View>
  );
}

// ==================== 样式 ====================

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
  fabricBox: {
    width: 120,
    height: 120,
    marginBottom: 12,
  },
  hint: {
    marginTop: 8,
    fontSize: 12,
    color: '#999',
    fontFamily: 'Courier',
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
