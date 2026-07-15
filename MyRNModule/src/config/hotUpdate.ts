export type HotUpdateInstallMode = 'on_next_restart' | 'immediate';

export interface HotUpdateConfig {
  enabled: boolean;
  manifestURL: string;
  channel: string;
  publicKey: string;
  requestTimeoutMs: number;
  autoCheckOnLaunch: boolean;
  installMode: HotUpdateInstallMode;
}

export const hotUpdateConfig: HotUpdateConfig = {
  enabled: true,
  manifestURL: '',
  channel: 'production',
  publicKey: '',
  requestTimeoutMs: 8000,
  autoCheckOnLaunch: true,
  installMode: 'on_next_restart',
};
