import React, { useState } from 'react';
import { Text, TextInput, View } from 'react-native';
import { Header } from '../../components/common/Header';
import {
  ActionButton,
  ResultCard,
  ScreenContainer,
  uiStyles,
} from '../../components/ui';
import { InterviewFabricCard } from '../../native/InterviewFabricCard';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function FabricViewScreen({ goBack }: ScreenProps) {
  const colors = ['#1D4ED8', '#7C3AED', '#059669', '#EA580C'];
  const [index, setIndex] = useState(0);
  const [label, setLabel] = useState('Fabric Native Card');
  const [radius, setRadius] = useState(16);
  const [width, setWidth] = useState(240);
  const [height, setHeight] = useState(140);

  return (
    <>
      <Header title="Fabric View" goBack={goBack} />
      <ScreenContainer
        title="Fabric Native Component Demo"
        summary="这个组件通过 codegenNativeComponent 定义 props，由 Android/iOS 原生 View 真正渲染。"
        points={[
          '不是旧版 requireNativeComponent 伪装',
          '文字、背景色、圆角通过 codegen props 下发',
          '宽高通过 ViewProps.style 走 Fabric 布局系统控制',
        ]}
      >
        <InterviewFabricCard
          label={label}
          cardBackgroundColor={colors[index]}
          cornerRadius={radius}
          width={width}
          height={height}
          style={demoStyles.fabricCard}
        />

        <ResultCard title="控制区">
          <Text style={uiStyles.label}>文本</Text>
          <TextInput
            style={uiStyles.input}
            value={label}
            onChangeText={setLabel}
          />
          <View style={demoStyles.buttonGroup}>
            <ActionButton
              title="切换背景色"
              onPress={() => setIndex(v => (v + 1) % colors.length)}
            />
            <ActionButton
              title="圆角 +"
              onPress={() => setRadius(v => v + 4)}
              variant="secondary"
            />
            <ActionButton
              title="圆角 -"
              onPress={() => setRadius(v => Math.max(0, v - 4))}
              variant="secondary"
            />
            <ActionButton title="宽 +" onPress={() => setWidth(v => v + 20)} />
            <ActionButton
              title="宽 -"
              onPress={() => setWidth(v => Math.max(160, v - 20))}
              variant="secondary"
            />
            <ActionButton title="高 +" onPress={() => setHeight(v => v + 12)} />
            <ActionButton
              title="高 -"
              onPress={() => setHeight(v => Math.max(100, v - 12))}
              variant="secondary"
            />
          </View>
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
