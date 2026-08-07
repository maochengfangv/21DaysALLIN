import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  onCardPress(cardId: string): void;
  onActionPress(cardId: string, actionId: string, actionType: Double): void;
  onExposure(cardId: string, timestamp: Double): void;
  getInitialCards(): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('BusinessCardBridge');
