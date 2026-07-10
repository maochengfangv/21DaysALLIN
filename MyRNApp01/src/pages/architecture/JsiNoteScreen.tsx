import React from 'react';
import { Text } from 'react-native';
import { Header } from '../../components/common/Header';
import { ResultCard, ScreenContainer } from '../../components/ui';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function JsiNoteScreen({ goBack }: ScreenProps) {
  return (
    <>
      <Header title="JSI Note" goBack={goBack} />
      <ScreenContainer
        title="JSI / Architecture Note Demo"
        summary="这里不做重成本 C++ demo，而是保留最小讲解页，帮助区分 JSI、TurboModule、Fabric。"
        points={[
          'JSI 是 JS 与 C++ Runtime 的更底层互操作能力',
          'TurboModule 是基于 JSI 的原生模块调用方案',
          'Fabric 是新的渲染系统，不等价于 TurboModule',
        ]}
      >
        <ResultCard title="区别说明">
          <Text style={demoStyles.resultText}>
            JSI：更底层，适合高性能计算、同步能力、C++ 封装。
          </Text>
          <Text style={demoStyles.resultText}>
            TurboModule：模块调用层，替代旧桥接 NativeModules。
          </Text>
          <Text style={demoStyles.resultText}>
            Fabric：UI 渲染层，替代旧 UIManager / Shadow Tree 链路。
          </Text>
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
