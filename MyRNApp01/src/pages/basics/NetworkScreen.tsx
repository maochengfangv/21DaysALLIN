import React, { useState } from 'react';
import { View } from 'react-native';
import { Header } from '../../components/common/Header';
import { ActionButton, ResultCard, ScreenContainer } from '../../components/ui';
import { fetchMockProfile } from '../../services/mockApi';
import { getErrorMessage } from '../../utils/error';
import { stringify } from '../../utils/logger';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function NetworkScreen({ goBack }: ScreenProps) {
  const [status, setStatus] = useState<
    'idle' | 'loading' | 'success' | 'error'
  >('idle');
  const [result, setResult] = useState('');

  const runRequest = async (shouldFail: boolean) => {
    setStatus('loading');
    setResult('');
    try {
      const response = await fetchMockProfile(shouldFail);
      setStatus('success');
      setResult(stringify(response));
    } catch (error) {
      setStatus('error');
      setResult(getErrorMessage(error));
    }
  };

  return (
    <>
      <Header title="Network Mock" goBack={goBack} />
      <ScreenContainer
        title="Network Mock Demo"
        summary="模拟请求封装与三态展示，便于讲解服务层抽象。"
        points={[
          'loading / success / error 三态齐全',
          'mock service 与页面解耦',
          '失败路径可重复演示',
        ]}
      >
        <View style={demoStyles.buttonGroup}>
          <ActionButton title="请求成功" onPress={() => runRequest(false)} />
          <ActionButton
            title="请求失败"
            onPress={() => runRequest(true)}
            variant="secondary"
          />
        </View>
        <ResultCard title={`当前状态：${status}`}>
          {result || '等待触发请求'}
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
