import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  /**
   * 获取当前计数值
   */
  getValue(): Promise<Double>;
  /**
   * 增加计数
   */
  increment(step: Double): Promise<Double>;
  /**
   * 减少计数
   */
  decrement(step: Double): Promise<Double>;
  /**
   * 重置计数
   */
  reset(): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeCounter');
