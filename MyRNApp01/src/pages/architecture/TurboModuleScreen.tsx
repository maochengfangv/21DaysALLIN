import React, { useState } from 'react';
import { View } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  ActionButton,
  MetricPill,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { envInfo } from '../../services/env';
import {
  InterviewTurboModule,
  isInterviewTurboModuleAvailable,
} from '../../native/InterviewTurboModule';
import { stringify } from '../../utils/logger';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function TurboModuleScreen({ goBack }: ScreenProps) {
  const [result, setResult] = useState('等待调用');

  const callDeviceInfo = () => {
    if (!InterviewTurboModule) {
      setResult('当前未拿到原生 TurboModule 实例');
      return;
    }
    setResult(stringify(InterviewTurboModule.getDeviceInfo()));
  };

  const callTimestamp = () => {
    if (!InterviewTurboModule) {
      setResult('当前未拿到原生 TurboModule 实例');
      return;
    }
    setResult(String(InterviewTurboModule.getTimestamp()));
  };

  const callTimestampAsync = async () => {
    if (!InterviewTurboModule) {
      setResult('当前未拿到原生 TurboModule 实例');
      return;
    }
    const value = await InterviewTurboModule.getTimestampAsync();
    setResult(`async timestamp: ${value}`);
  };

  const callLog = () => {
    if (!InterviewTurboModule) {
      setResult('当前未拿到原生 TurboModule 实例');
      return;
    }
    InterviewTurboModule.logNativeMessage('Hello from RN TurboModule page');
    setResult('已调用原生日志/提示能力');
  };

  return (
    <>
      <Header title="TurboModule" goBack={goBack} />
      <ScreenContainer
        title="TurboModule Demo"
        summary="这里使用的是 TurboModule + Codegen，不是旧架构里的 NativeModules 手写桥。"
        points={[
          'TS spec 参与 codegen，Native 直接继承生成的 Spec',
          '支持同步 getTimestamp 与异步 getTimestampAsync',
          '页面能看到返回结果，可用于面试现场演示',
        ]}
      >
        <View style={uiStyles.row}>
          <MetricPill
            label="Available"
            value={String(isInterviewTurboModuleAvailable)}
          />
          <MetricPill label="Hermes" value={String(envInfo.hermesEnabled)} />
          <MetricPill label="Fabric" value={String(envInfo.fabricEnabled)} />
        </View>
        <View style={demoStyles.buttonGroup}>
          <ActionButton title="getDeviceInfo()" onPress={callDeviceInfo} />
          <ActionButton
            title="getTimestamp()"
            onPress={callTimestamp}
            variant="secondary"
          />
          <ActionButton
            title="getTimestampAsync()"
            onPress={callTimestampAsync}
            variant="secondary"
          />
          <ActionButton title="logNativeMessage()" onPress={callLog} />
        </View>
        <ResultCard title="返回结果">{result}</ResultCard>
      </ScreenContainer>
    </>
  );
}
