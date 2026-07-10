import type React from 'react';
import { HomeScreen } from './home/HomeScreen';
import { HooksScreen } from './basics/HooksScreen';
import { FlatListScreen } from './basics/FlatListScreen';
import { FormScreen } from './basics/FormScreen';
import { NetworkScreen } from './basics/NetworkScreen';
import { CustomHookScreen } from './basics/CustomHookScreen';
import { ErrorBoundaryScreen } from './basics/ErrorBoundaryScreen';
import { RenderOptimizationScreen } from './performance/RenderOptimizationScreen';
import { InteractionScreen } from './performance/InteractionScreen';
import { PerformanceNotesScreen } from './performance/PerformanceNotesScreen';
import { TurboModuleScreen } from './architecture/TurboModuleScreen';
import { FabricViewScreen } from './architecture/FabricViewScreen';
import { JsiNoteScreen } from './architecture/JsiNoteScreen';
import { EnvConfigScreen } from './engineering/EnvConfigScreen';
import type { ScreenProps } from './types';
import type { RouteKey } from '../types/demo';

export const Screens: Record<RouteKey, React.ComponentType<ScreenProps>> = {
  home: HomeScreen,
  hooks: HooksScreen,
  flatlist: FlatListScreen,
  form: FormScreen,
  network: NetworkScreen,
  customHook: CustomHookScreen,
  errorBoundary: ErrorBoundaryScreen,
  renderOptimization: RenderOptimizationScreen,
  interaction: InteractionScreen,
  performanceNotes: PerformanceNotesScreen,
  turboModule: TurboModuleScreen,
  fabricView: FabricViewScreen,
  jsiNote: JsiNoteScreen,
  envConfig: EnvConfigScreen,
};

export type { ScreenProps } from './types';
