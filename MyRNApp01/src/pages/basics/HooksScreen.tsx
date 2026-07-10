import React, {
  memo,
  useCallback,
  useMemo,
  useReducer,
  useRef,
  useState,
} from 'react';
import { Text, TextInput, View } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  ActionButton,
  MetricPill,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function HooksScreen({ goBack }: ScreenProps) {
  const [count, setCount] = useState(0);
  const [keyword, setKeyword] = useState('TurboModule');
  const [state, dispatch] = useReducer(
    (prev: { score: number }, action: 'inc' | 'dec') => ({
      score: action === 'inc' ? prev.score + 1 : prev.score - 1,
    }),
    { score: 5 },
  );

  const parentRenderRef = useRef(0);
  parentRenderRef.current += 1;

  const expensiveValue = useMemo(() => {
    let total = 0;
    for (let i = 0; i < 2000; i += 1) {
      total += i;
    }
    return `${keyword} / ${total}`;
  }, [keyword]);

  const stableCallback = useCallback(() => setCount(v => v + 1), []);

  return (
    <>
      <Header title="Hooks Demo" goBack={goBack} />
      <ScreenContainer
        title="Hooks Demo"
        summary="通过同屏展示 state、reducer、memo、callback，直观看到 render 次数与对象引用稳定性的差异。"
        points={[
          '父组件 render 次数可视化',
          'useMemo 缓存派生值，避免重复计算',
          'useCallback + memo 让子组件减少无意义重渲染',
        ]}
      >
        <View style={uiStyles.row}>
          <MetricPill label="Parent Render" value={parentRenderRef.current} />
          <MetricPill label="useState Count" value={count} />
          <MetricPill label="Reducer Score" value={state.score} />
        </View>

        <ResultCard title="操作区">
          <View style={demoStyles.buttonGroup}>
            <ActionButton
              title="state +1"
              onPress={() => setCount(v => v + 1)}
            />
            <ActionButton
              title="reducer +1"
              onPress={() => dispatch('inc')}
              variant="secondary"
            />
            <ActionButton
              title="reducer -1"
              onPress={() => dispatch('dec')}
              variant="secondary"
            />
          </View>
          <TextInput
            value={keyword}
            onChangeText={setKeyword}
            placeholder="输入关键词观察 useMemo"
            style={uiStyles.input}
          />
          <Text style={demoStyles.resultText}>派生值：{expensiveValue}</Text>
        </ResultCard>

        <ResultCard title="重渲染对比">
          <PlainChild
            label="未优化子组件"
            onPress={() => setCount(v => v + 1)}
          />
          <MemoChild
            label="memo + useCallback 子组件"
            onPress={stableCallback}
          />
        </ResultCard>
      </ScreenContainer>
    </>
  );
}

function PlainChild({
  label,
  onPress,
}: {
  label: string;
  onPress: () => void;
}) {
  const renderRef = useRef(0);
  renderRef.current += 1;

  return (
    <View style={demoStyles.childCard}>
      <Text style={demoStyles.childTitle}>{label}</Text>
      <Text style={demoStyles.resultText}>render: {renderRef.current}</Text>
      <ActionButton title="触发" onPress={onPress} variant="secondary" />
    </View>
  );
}

const MemoChild = memo(
  ({ label, onPress }: { label: string; onPress: () => void }) => {
    const renderRef = useRef(0);
    renderRef.current += 1;

    return (
      <View style={demoStyles.childCard}>
        <Text style={demoStyles.childTitle}>{label}</Text>
        <Text style={demoStyles.resultText}>render: {renderRef.current}</Text>
        <ActionButton title="触发" onPress={onPress} variant="secondary" />
      </View>
    );
  },
);
