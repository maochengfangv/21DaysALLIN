import type { HotUpdateInstallMode } from '../../config/hotUpdate';

export enum HotUpdateStatus {
  IDLE = 'idle',
  DISABLED = 'disabled',
  CHECKING = 'checking',
  UP_TO_DATE = 'up_to_date',
  UPDATE_AVAILABLE = 'update_available',
  DOWNLOADING = 'downloading',
  VERIFYING = 'verifying',
  READY = 'ready',
  INSTALLING = 'installing',
  ERROR = 'error',
  ROLLBACK = 'rollback',
}

export interface HotUpdateProgress {
  totalBytes: number;
  receivedBytes: number;
  percentage: number;
}

export interface HotUpdateManifest {
  id: string;
  label: string;
  platform: 'ios' | 'android';
  channel: string;
  version: string;
  packageUrl: string;
  packageSha256: string;
  bundleFile: string;
  bundleSha256: string;
  description?: string;
  mandatory?: boolean;
  rollout?: number;
  minNativeVersion?: string;
  packageType?: 'full' | 'patch';
  signature?: string;
  signatureAlgorithm?: 'RSA-SHA256';
  createdAt?: string;
}

export interface InstalledHotUpdatePackage {
  id: string;
  label: string;
  description?: string;
  channel: string;
  platform: 'ios' | 'android';
  packageDir: string;
  bundlePath: string;
  packageSha256: string;
  bundleSha256: string;
  installMode: HotUpdateInstallMode;
  installedAt: string;
}

export interface HotUpdateState {
  installationId: string;
  currentPackageId: string | null;
  previousPackageId: string | null;
  pendingPackageId: string | null;
  pendingAttempted: boolean;
  packages: Record<string, InstalledHotUpdatePackage>;
}

export interface HotUpdateVersionInfo {
  appVersion: string;
  buildNumber: string;
  currentLabel: string;
  description: string;
  isPending: boolean;
}

export type HotUpdateListener = (
  status: HotUpdateStatus,
  progress?: HotUpdateProgress,
) => void;
