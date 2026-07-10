import React, { memo, useCallback, useMemo, useRef, useState } from 'react';
import { Text, View } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  ActionButton,
  MetricPill,
  ResultCard,
  ScreenContainer,
} from '../../components/ui';
import { stringify } from '../../utils/logger';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function RenderOptimizationScreen({ goBack }: ScreenProps) {
  const [themeTick, setThemeTick] = useState(0);
  const [keyword, setKeyword] = useState('fabric');

  const memoPayload = useMemo(
    () => ({ keyword, tag: 'memo-payload' }),
    [keyword],
  );

  const stableChange = useCallback((value: string) => {
    setKeyword(value);
  }, []);

  return (
    <>
      <Header title="Render Optimization" goBack={goBack} />
      <ScreenContainer
        title="Render Optimization Demo"
        summary="展示对象引用与回调引用是否稳定，直接影响 memo 子组件是否重渲染。"
        points={[
          '没有 useMemo / useCallback 时，浅比较经常失效',
          'memo 不是银弹，前提是 props 稳定',
          '优化应基于热点组件与 profiling',
        ]}
      >
        <View style={demoStyles.buttonGroup}>
          <ActionButton
            title="触发无关状态更新"
            onPress={() => setThemeTick(v => v + 1)}
          />
          <MetricPill label="ThemeTick" value={themeTick} />
        </View>
        <ResultCard title="未优化 vs 已优化">
          <NonMemoBlock payload={{ keyword, tag: 'new-object' }} />
          <MemoBlock payload={memoPayload} onKeywordChange={stableChange} />
        </ResultCard>
      </ScreenContainer>
    </>
  );
}

function NonMemoBlock({
  payload,
}: {
  payload: { keyword: string; tag: string };
}) {
  const renderRef = useRef(0);
  renderRef.current += 1;

  return (
    <View style={demoStyles.childCard}>
      <Text style={demoStyles.childTitle}>未优化块</Text>
      <Text style={demoStyles.resultText}>render: {renderRef.current}</Text>
      <Text style={demoStyles.resultText}>{stringify(payload)}</Text>
    </View>
  );
}

const MemoBlock = memo(
  ({
    payload,
    onKeywordChange,
  }: {
    payload: { keyword: string; tag: string };
    onKeywordChange: (value: string) => void;
  }) => {
    const renderRef = useRef(0);
    renderRef.current += 1;

    return (
      <View style={demoStyles.childCard}>
        <Text style={demoStyles.childTitle}>已优化块</Text>
        <Text style={demoStyles.resultText}>render: {renderRef.current}</Text>
        <Text style={demoStyles.resultText}>{stringify(payload)}</Text>
        <ActionButton
          title="改关键词"
          onPress={() => onKeywordChange(`${payload.keyword}!`)}
          variant="secondary"
        />
      </View>
    );
  },
);
