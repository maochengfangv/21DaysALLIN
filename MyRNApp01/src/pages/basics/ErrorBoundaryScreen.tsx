import React, { useState } from 'react';
import { Text } from 'react-native';
import { Header } from '../../components/common/Header';
import { ActionButton, ResultCard, ScreenContainer } from '../../components/ui';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function ErrorBoundaryScreen({
  goBack,
  lastGlobalError,
  clearGlobalError,
}: ScreenProps) {
  const [shouldCrash, setShouldCrash] = useState(false);

  return (
    <>
      <Header title="Error Boundary" goBack={goBack} />
      <ScreenContainer
        title="Error Boundary Demo"
        summary="页面级 boundary 负责兜住渲染异常；全局 handler 负责兜住未捕获错误并记录。"
        points={[
          'Boundary 只能兜渲染树内部异常',
          '全局 handler 负责更大范围的异常观测',
          '面试里可延伸到 Sentry / 埋点平台',
        ]}
      >
        <InlineErrorBoundary>
          {shouldCrash ? <CrashedCard /> : null}
        </InlineErrorBoundary>
        <ActionButton
          title="触发渲染异常"
          onPress={() => setShouldCrash(true)}
        />
        <ResultCard title="全局错误捕获">
          <Text style={demoStyles.resultText}>
            {lastGlobalError || '当前无全局异常'}
          </Text>
          <ActionButton
            title="清空"
            onPress={clearGlobalError}
            variant="secondary"
          />
        </ResultCard>
      </ScreenContainer>
    </>
  );
}

class InlineErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { message: string | null }
> {
  state = { message: null };

  static getDerivedStateFromError(error: Error) {
    return { message: error.message };
  }

  render() {
    if (this.state.message) {
      return (
        <ResultCard title="Boundary 捕获结果">
          <Text style={demoStyles.errorText}>{this.state.message}</Text>
        </ResultCard>
      );
    }
    return this.props.children;
  }
}

function CrashedCard(): React.JSX.Element {
  throw new Error('这是一个由 Error Boundary 捕获的渲染异常');
}
