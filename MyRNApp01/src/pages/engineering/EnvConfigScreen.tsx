import React from 'react';
import { Header } from '../../components/common/Header';
import { ResultCard, ScreenContainer } from '../../components/ui';
import { envInfo } from '../../services/env';
import { stringify } from '../../utils/logger';
import type { ScreenProps } from '../types';

export function EnvConfigScreen({ goBack }: ScreenProps) {
  return (
    <>
      <Header title="Env Config" goBack={goBack} />
      <ScreenContainer
        title="Env Config Demo"
        summary="这个页面展示运行环境信息，也方便讲解 dev / prod 配置、日志封装与错误工具。"
        points={[
          'env service 统一聚合运行时信息',
          'logger / error helper 让业务层更薄',
          '真实项目可继续扩展多环境配置文件',
        ]}
      >
        <ResultCard title="当前环境">{stringify(envInfo)}</ResultCard>
      </ScreenContainer>
    </>
  );
}
