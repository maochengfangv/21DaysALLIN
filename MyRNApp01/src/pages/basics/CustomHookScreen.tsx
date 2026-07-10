import React, { useState } from 'react';
import { Text, TextInput } from 'react-native';
import { Header } from '../../components/common/Header';
import { ResultCard, ScreenContainer, uiStyles } from '../../components/ui';
import { useDebouncedValue } from '../../hooks/useDebouncedValue';
import { useMountedRef } from '../../hooks/useMountedRef';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function CustomHookScreen({ goBack }: ScreenProps) {
  const [keyword, setKeyword] = useState('');
  const debounced = useDebouncedValue(keyword, 600);
  const mountedRef = useMountedRef();

  return (
    <>
      <Header title="Custom Hook" goBack={goBack} />
      <ScreenContainer
        title="Custom Hook Demo"
        summary="使用 debounce hook 展示真实搜索场景；mountedRef 用于异步回调前判断组件是否还在。"
        points={[
          'debounce 适合搜索联想与输入降频',
          'mountedRef 避免卸载后 setState',
          '这类 hook 在业务项目里复用价值很高',
        ]}
      >
        <ResultCard title="输入联想">
          <TextInput
            style={uiStyles.input}
            value={keyword}
            onChangeText={setKeyword}
            placeholder="输入 React Native / Fabric / JSI"
          />
          <Text style={demoStyles.resultText}>原始输入：{keyword || '-'}</Text>
          <Text style={demoStyles.resultText}>
            Debounced：{debounced || '-'}
          </Text>
          <Text style={demoStyles.resultText}>
            mountedRef：{String(mountedRef.current)}
          </Text>
        </ResultCard>
      </ScreenContainer>
    </>
  );
}
