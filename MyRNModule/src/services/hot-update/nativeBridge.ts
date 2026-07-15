import { NativeModules } from 'react-native';

interface HotUpdateBridgeModule {
  getCurrentBundlePath(): Promise<string | null>;
  setCurrentBundlePath(bundlePath: string): Promise<void>;
  clearCurrentBundlePath(): Promise<void>;
  getEmbeddedBundlePath(): Promise<string | null>;
  reloadBundle(bundlePath?: string | null): Promise<void>;
  getAppVersion(): Promise<string>;
  getBuildNumber(): Promise<string>;
}

const nativeBridge = NativeModules.HotUpdateBridge as
  | Partial<HotUpdateBridgeModule>
  | undefined;

const fallbackBridge: HotUpdateBridgeModule = {
  async getCurrentBundlePath() {
    return null;
  },
  async setCurrentBundlePath() {},
  async clearCurrentBundlePath() {},
  async getEmbeddedBundlePath() {
    return null;
  },
  async reloadBundle() {},
  async getAppVersion() {
    return '0.0.0';
  },
  async getBuildNumber() {
    return '0';
  },
};

export const hotUpdateNativeBridge: HotUpdateBridgeModule = {
  getCurrentBundlePath:
    nativeBridge?.getCurrentBundlePath?.bind(nativeBridge) ??
    fallbackBridge.getCurrentBundlePath,
  setCurrentBundlePath:
    nativeBridge?.setCurrentBundlePath?.bind(nativeBridge) ??
    fallbackBridge.setCurrentBundlePath,
  clearCurrentBundlePath:
    nativeBridge?.clearCurrentBundlePath?.bind(nativeBridge) ??
    fallbackBridge.clearCurrentBundlePath,
  getEmbeddedBundlePath:
    nativeBridge?.getEmbeddedBundlePath?.bind(nativeBridge) ??
    fallbackBridge.getEmbeddedBundlePath,
  reloadBundle:
    nativeBridge?.reloadBundle?.bind(nativeBridge) ??
    fallbackBridge.reloadBundle,
  getAppVersion:
    nativeBridge?.getAppVersion?.bind(nativeBridge) ??
    fallbackBridge.getAppVersion,
  getBuildNumber:
    nativeBridge?.getBuildNumber?.bind(nativeBridge) ??
    fallbackBridge.getBuildNumber,
};
