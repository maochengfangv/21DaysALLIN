import { Platform } from 'react-native';

const runtime = globalThis as typeof globalThis & {
  HermesInternal?: unknown;
  nativeFabricUIManager?: unknown;
  RN$Bridgeless?: boolean;
};

const rnVersion = Platform.constants?.reactNativeVersion;
const versionText = rnVersion
  ? `${rnVersion.major}.${rnVersion.minor}.${rnVersion.patch}`
  : 'unknown';

export const envInfo = {
  mode: __DEV__ ? 'dev' : 'prod',
  platform: Platform.OS,
  reactNativeVersion: versionText,
  hermesEnabled: Boolean(runtime.HermesInternal),
  fabricEnabled: Boolean(runtime.nativeFabricUIManager),
  bridgelessHint: Boolean(runtime.RN$Bridgeless),
};
