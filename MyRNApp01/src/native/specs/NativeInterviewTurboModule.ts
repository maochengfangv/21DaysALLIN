import {TurboModuleRegistry, type TurboModule} from 'react-native';
import type {Double} from 'react-native/Libraries/Types/CodegenTypes';

export type DeviceInfo = {
  platform: string;
  systemVersion: string;
  model: string;
  appVersion: string;
  isHermes: boolean;
  isNewArchitecture: boolean;
};

export interface Spec extends TurboModule {
  getDeviceInfo(): DeviceInfo;
  getTimestamp(): Double;
  getTimestampAsync(): Promise<Double>;
  logNativeMessage(message: string): void;
}

export default TurboModuleRegistry.get<Spec>('InterviewTurboModule');
