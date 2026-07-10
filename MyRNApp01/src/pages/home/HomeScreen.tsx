import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { ScreenContainer, ResultCard } from '../../components/ui';
import { demoCatalog } from '../../configs/demoRegistry';
import { demoStyles } from '../shared/demoStyles';
import type { ScreenProps } from '../types';

export function HomeScreen({ navigate }: ScreenProps) {
  return (
    <ScreenContainer
      title="RN 面试技能地图 Demo"
      summary="这是一个偏面试展示的可运行 Demo App：覆盖 RN 基础、性能优化、新架构与工程化，适合用作项目讲解载体。"
      points={[
        '所有入口都能点进去看到交互与可见结果',
        'TurboModule 与 Fabric 走真正的新架构 codegen 链路',
        '首页结构与目录层次按面试作品组织',
      ]}
    >
      {demoCatalog.map(section => (
        <ResultCard key={section.section} title={section.section}>
          <View style={demoStyles.catalogList}>
            {section.items.map(item => (
              <Pressable
                key={item.route}
                onPress={() => navigate(item.route)}
                style={demoStyles.catalogItem}
              >
                <Text style={demoStyles.catalogTitle}>{item.title}</Text>
                <Text style={demoStyles.catalogSubtitle}>{item.subtitle}</Text>
              </Pressable>
            ))}
          </View>
        </ResultCard>
      ))}
    </ScreenContainer>
  );
}
