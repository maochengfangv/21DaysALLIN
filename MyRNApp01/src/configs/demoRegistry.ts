import type { DemoSection } from '../types/demo';

export const demoCatalog: DemoSection[] = [
  {
    section: 'RN Basics',
    items: [
      {
        route: 'hooks',
        title: 'Hooks Demo',
        subtitle: '状态、reducer、memo 对比',
      },
      {
        route: 'flatlist',
        title: 'FlatList Performance Demo',
        subtitle: '长列表、分页、刷新、memo item',
      },
      {
        route: 'form',
        title: 'Form Validation Demo',
        subtitle: '输入校验与提交态',
      },
      {
        route: 'network',
        title: 'Network Mock Demo',
        subtitle: 'loading / success / error',
      },
      {
        route: 'customHook',
        title: 'Custom Hook Demo',
        subtitle: 'debounce + mountedRef',
      },
      {
        route: 'errorBoundary',
        title: 'Error Boundary Demo',
        subtitle: '页面异常边界与全局兜底',
      },
    ],
  },
  {
    section: 'Performance',
    items: [
      {
        route: 'renderOptimization',
        title: 'Render Optimization Demo',
        subtitle: 'memo / useMemo / useCallback',
      },
      {
        route: 'interaction',
        title: 'Interaction Demo',
        subtitle: 'InteractionManager / RAF',
      },
      {
        route: 'performanceNotes',
        title: 'Performance Notes Demo',
        subtitle: '首屏、列表、Bridge 开销讲解',
      },
    ],
  },
  {
    section: 'New Architecture',
    items: [
      {
        route: 'turboModule',
        title: 'TurboModule Demo',
        subtitle: 'Codegen + 双端 Native 能力',
      },
      {
        route: 'fabricView',
        title: 'Fabric View Demo',
        subtitle: 'Codegen + 原生自定义 View',
      },
      {
        route: 'jsiNote',
        title: 'JSI / Architecture Note Demo',
        subtitle: 'JSI 与 TurboModule / Fabric 区分',
      },
    ],
  },
  {
    section: 'Engineering',
    items: [
      {
        route: 'envConfig',
        title: 'Env Config Demo',
        subtitle: '环境信息、统一日志、错误工具',
      },
    ],
  },
];
