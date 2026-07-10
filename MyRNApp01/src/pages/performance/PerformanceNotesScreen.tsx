import React from 'react';
import { Text } from 'react-native';
import { Header } from '../../components/common/Header';
import { ResultCard, ScreenContainer } from '../../components/ui';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function PerformanceNotesScreen({ goBack }: ScreenProps) {
  return (
    <>
      <Header title="Performance Notes" goBack={goBack} />
      <ScreenContainer
        title="Performance Notes Demo"
        summary="这个页面偏讲解，用可视化文字承载面试时的性能优化表达。"
        points={[
          'Bridge 时代跨端序列化成本更高，新架构减少层次',
          '长列表核心是首屏渲染量、item 稳定性、分页策略',
          '首屏优化关注 bundle 体积、任务拆分、预加载与缓存',
        ]}
      >
        <ResultCard title="可讲点">
          <Text style={demoStyles.resultText}>
            1. 大对象跨桥通信会带来序列化与线程切换成本。
          </Text>
          <Text style={demoStyles.resultText}>
            2. Fabric 让渲染树和布局链路更贴近原生渲染模型。
          </Text>
          <Text style={demoStyles.resultText}>
            3. TurboModule 支持 lazy load，同步能力更适合小粒度高频调用。
          </Text>
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
