import React, { useState } from 'react';
import { InteractionManager, Text, View } from 'react-native';
import { Header } from '../../components/common/Header';
import { ActionButton, ResultCard, ScreenContainer } from '../../components/ui';
import { wait } from '../../services/mockApi';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function InteractionScreen({ goBack }: ScreenProps) {
  const [rafMessage, setRafMessage] = useState('未执行');
  const [interactionMessage, setInteractionMessage] = useState('未执行');

  const runRAF = () => {
    requestAnimationFrame(() => {
      setRafMessage(`RAF 在下一帧执行：${Date.now()}`);
    });
  };

  const runAfterInteraction = () => {
    InteractionManager.runAfterInteractions(async () => {
      await wait(120);
      setInteractionMessage(`Interaction 任务已执行：${Date.now()}`);
    });
  };

  return (
    <>
      <Header title="Interaction Demo" goBack={goBack} />
      <ScreenContainer
        title="Interaction Demo"
        summary="把非关键任务挪到交互后执行，减少首帧或动画期间卡顿。"
        points={[
          'requestAnimationFrame 适合对齐下一帧',
          'runAfterInteractions 适合把低优先级任务延后',
          '面试里可以结合启动任务拆分来讲',
        ]}
      >
        <View style={demoStyles.buttonGroup}>
          <ActionButton title="执行 RAF" onPress={runRAF} />
          <ActionButton
            title="交互后执行"
            onPress={runAfterInteraction}
            variant="secondary"
          />
        </View>
        <ResultCard title="结果">
          <Text style={demoStyles.resultText}>{rafMessage}</Text>
          <Text style={demoStyles.resultText}>{interactionMessage}</Text>
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
