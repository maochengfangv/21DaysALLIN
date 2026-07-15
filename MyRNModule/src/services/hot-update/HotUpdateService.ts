import { Platform } from 'react-native';
import RNFS from 'react-native-fs';
import { unzip } from 'react-native-zip-archive';
import { hotUpdateConfig } from '../../config/hotUpdate';
import { hotUpdateNativeBridge } from './nativeBridge';
import type {
  HotUpdateListener,
  HotUpdateManifest,
  HotUpdateProgress,
  HotUpdateState,
  HotUpdateVersionInfo,
  InstalledHotUpdatePackage,
} from './types';
import { HotUpdateStatus } from './types';

// jsrsasign 在 verifyManifestSignature 中惰性加载，避免 Metro 打包时因 Node.js crypto 依赖失败
let _jsrsasign: any;

function getJsrsasign(): any {
  if (!_jsrsasign) {
    _jsrsasign = require('jsrsasign');
  }
  return _jsrsasign;
}

// 路径常量使用 getter 延迟访问 RNFS.DocumentDirectoryPath，避免原生模块未就绪时抛出异常
function otaRootDir(): string {
  return `${RNFS.DocumentDirectoryPath}/hot-updates`;
}
function otaDownloadDir(): string {
  return `${otaRootDir()}/downloads`;
}
function otaPackageDir(): string {
  return `${otaRootDir()}/packages`;
}
function otaStateFile(): string {
  return `${otaRootDir()}/state.json`;
}

function createDefaultState(): HotUpdateState {
  return {
    installationId: '',
    currentPackageId: null,
    previousPackageId: null,
    pendingPackageId: null,
    pendingAttempted: false,
    packages: {},
  };
}

class HotUpdateService {
  private status = HotUpdateStatus.IDLE;
  private progress: HotUpdateProgress | undefined;
  private listeners = new Set<HotUpdateListener>();

  addListener(listener: HotUpdateListener) {
    this.listeners.add(listener);
  }

  removeListener(listener: HotUpdateListener) {
    this.listeners.delete(listener);
  }

  getStatus() {
    return this.status;
  }

  getProgress() {
    return this.progress;
  }

  async initialize(): Promise<void> {
    await this.ensureStorage();
    let state = await this.readState();
    if (!state.installationId) {
      state.installationId = this.createInstallationId();
      await this.writeState(state);
    }

    state = await this.pruneMissingPackages(state);

    if (state.pendingPackageId) {
      if (state.pendingAttempted) {
        await this.rollbackPendingUpdate(state.pendingPackageId);
        return;
      }

      state.pendingAttempted = true;
      await this.writeState(state);
    }

    if (!hotUpdateConfig.enabled) {
      this.notify(HotUpdateStatus.DISABLED);
      return;
    }

    this.notify(HotUpdateStatus.IDLE);
  }

  async markApplicationReady(): Promise<void> {
    const state = await this.readState();
    if (!state.pendingPackageId) {
      return;
    }

    state.pendingPackageId = null;
    state.pendingAttempted = false;
    await this.writeState(state);

    this.notify(HotUpdateStatus.READY);
  }

  async autoCheckForUpdate(): Promise<void> {
    if (!hotUpdateConfig.enabled || !hotUpdateConfig.autoCheckOnLaunch) {
      return;
    }

    try {
      const manifest = await this.checkForUpdate(true);
      if (manifest) {
        await this.downloadAndInstall(manifest, hotUpdateConfig.installMode);
      }
    } catch (error) {
      this.handleError(error);
    }
  }

  async checkForUpdate(silent = false): Promise<HotUpdateManifest | null> {
    if (!hotUpdateConfig.enabled || !hotUpdateConfig.manifestURL) {
      this.notify(HotUpdateStatus.DISABLED);
      return null;
    }

    this.notify(HotUpdateStatus.CHECKING);

    try {
      const manifest = await this.fetchManifest();
      await this.validateManifest(manifest);

      if (!(await this.isRolloutMatched(manifest))) {
        this.notify(HotUpdateStatus.UP_TO_DATE);
        return null;
      }

      const state = await this.readState();
      const currentPackage = state.currentPackageId
        ? state.packages[state.currentPackageId]
        : null;

      if (currentPackage?.id === manifest.id) {
        this.notify(HotUpdateStatus.UP_TO_DATE);
        return null;
      }

      if (!silent) {
        this.notify(HotUpdateStatus.UPDATE_AVAILABLE);
      } else {
        this.notify(HotUpdateStatus.UPDATE_AVAILABLE);
      }

      return manifest;
    } catch (error) {
      this.handleError(error);
      return null;
    }
  }

  async downloadAndInstall(
    manifest: HotUpdateManifest,
    installMode = hotUpdateConfig.installMode,
  ): Promise<void> {
    this.notify(HotUpdateStatus.DOWNLOADING, {
      totalBytes: 0,
      receivedBytes: 0,
      percentage: 0,
    });

    const zipFilePath = `${otaDownloadDir()}/${manifest.id}.zip`;
    const stagingDir = `${otaPackageDir()}/${manifest.id}-staging`;
    const finalDir = `${otaPackageDir()}/${manifest.id}`;

    await RNFS.unlink(zipFilePath).catch(() => undefined);
    await RNFS.unlink(stagingDir).catch(() => undefined);
    await RNFS.unlink(finalDir).catch(() => undefined);

    try {
      await this.downloadPackage(manifest.packageUrl, zipFilePath);
      this.notify(HotUpdateStatus.VERIFYING, this.progress);

      await this.verifyFileHash(zipFilePath, manifest.packageSha256, '更新包哈希不匹配');

      await unzip(zipFilePath, stagingDir);

      const bundlePath = `${stagingDir}/${manifest.bundleFile}`;
      const bundleExists = await RNFS.exists(bundlePath);
      if (!bundleExists) {
        throw new Error(`未找到 bundle 文件: ${manifest.bundleFile}`);
      }

      await this.verifyFileHash(bundlePath, manifest.bundleSha256, 'bundle 哈希不匹配');
      await this.verifyManifestSignature(manifest);

      await RNFS.moveFile(stagingDir, finalDir);
      await RNFS.unlink(zipFilePath).catch(() => undefined);

      const installedPackage: InstalledHotUpdatePackage = {
        id: manifest.id,
        label: manifest.label,
        description: manifest.description,
        channel: manifest.channel,
        platform: manifest.platform,
        packageDir: finalDir,
        bundlePath: `${finalDir}/${manifest.bundleFile}`,
        packageSha256: manifest.packageSha256,
        bundleSha256: manifest.bundleSha256,
        installMode,
        installedAt: new Date().toISOString(),
      };

      await this.activatePackage(installedPackage);

      if (installMode === 'immediate') {
        this.notify(HotUpdateStatus.INSTALLING);
        await hotUpdateNativeBridge.reloadBundle(installedPackage.bundlePath);
      } else {
        this.notify(HotUpdateStatus.READY);
      }
    } catch (error) {
      await RNFS.unlink(zipFilePath).catch(() => undefined);
      await RNFS.unlink(stagingDir).catch(() => undefined);
      this.handleError(error);
      throw error;
    }
  }

  async restartApp(): Promise<void> {
    const currentBundlePath = await hotUpdateNativeBridge.getCurrentBundlePath();
    await hotUpdateNativeBridge.reloadBundle(currentBundlePath);
  }

  async getCurrentVersion(): Promise<HotUpdateVersionInfo> {
    const [appVersion, buildNumber, state] = await Promise.all([
      hotUpdateNativeBridge.getAppVersion(),
      hotUpdateNativeBridge.getBuildNumber(),
      this.readState(),
    ]);

    const currentPackage = state.currentPackageId
      ? state.packages[state.currentPackageId]
      : null;

    return {
      appVersion,
      buildNumber,
      currentLabel: currentPackage?.label ?? appVersion,
      description: currentPackage?.description ?? '内置版本',
      isPending: Boolean(state.pendingPackageId),
    };
  }

  private notify(status: HotUpdateStatus, progress?: HotUpdateProgress) {
    this.status = status;
    this.progress = progress;
    this.listeners.forEach(listener => listener(status, progress));
  }

  private handleError(error: unknown) {
    console.error('[HotUpdate]', error);
    this.notify(HotUpdateStatus.ERROR, this.progress);
  }

  private async ensureStorage() {
    await Promise.all([
      RNFS.mkdir(otaRootDir()),
      RNFS.mkdir(otaDownloadDir()),
      RNFS.mkdir(otaPackageDir()),
    ]);
  }

  private async readState(): Promise<HotUpdateState> {
    const exists = await RNFS.exists(otaStateFile());
    if (!exists) {
      const initialState = createDefaultState();
      await this.writeState(initialState);
      return initialState;
    }

    try {
      const raw = await RNFS.readFile(otaStateFile(), 'utf8');
      const parsed = JSON.parse(raw) as Partial<HotUpdateState>;
      return {
        ...createDefaultState(),
        ...parsed,
        packages: {
          ...createDefaultState().packages,
          ...(parsed.packages ?? {}),
        },
      };
    } catch {
      const initialState = createDefaultState();
      await this.writeState(initialState);
      return initialState;
    }
  }

  private async writeState(state: HotUpdateState) {
    await RNFS.writeFile(otaStateFile(), JSON.stringify(state, null, 2), 'utf8');
  }

  private async fetchManifest(): Promise<HotUpdateManifest> {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      hotUpdateConfig.requestTimeoutMs,
    );

    try {
      const response = await fetch(
        `${hotUpdateConfig.manifestURL}?platform=${Platform.OS}&channel=${hotUpdateConfig.channel}`,
        { signal: controller.signal },
      );

      if (!response.ok) {
        throw new Error(`检查更新失败: HTTP ${response.status}`);
      }

      return (await response.json()) as HotUpdateManifest;
    } finally {
      clearTimeout(timer);
    }
  }

  private async validateManifest(manifest: HotUpdateManifest) {
    if (manifest.platform !== Platform.OS) {
      throw new Error(`Manifest 平台不匹配: ${manifest.platform}`);
    }

    if (!manifest.id || !manifest.label || !manifest.packageUrl) {
      throw new Error('Manifest 缺少必要字段');
    }

    if (!manifest.bundleFile || !manifest.packageSha256 || !manifest.bundleSha256) {
      throw new Error('Manifest 缺少校验字段');
    }

    if (
      manifest.minNativeVersion &&
      !this.isVersionSatisfied(
        await hotUpdateNativeBridge.getAppVersion(),
        manifest.minNativeVersion,
      )
    ) {
      throw new Error(
        `原生版本不满足更新要求: ${manifest.minNativeVersion}`,
      );
    }
  }

  private async isRolloutMatched(manifest: HotUpdateManifest): Promise<boolean> {
    const rollout = manifest.rollout ?? 100;
    if (rollout >= 100) {
      return true;
    }

    const state = await this.readState();
    const bucket = this.hashToBucket(`${state.installationId}:${manifest.id}`);
    return bucket < rollout;
  }

  private async downloadPackage(packageUrl: string, destination: string) {
    const result = RNFS.downloadFile({
      fromUrl: packageUrl,
      toFile: destination,
      progressDivider: 5,
      progress: ({ bytesWritten, contentLength }) => {
        const progress = {
          totalBytes: contentLength,
          receivedBytes: bytesWritten,
          percentage: contentLength > 0 ? bytesWritten / contentLength : 0,
        };
        this.notify(HotUpdateStatus.DOWNLOADING, progress);
      },
    });

    const response = await result.promise;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`下载更新包失败: HTTP ${response.statusCode}`);
    }
  }

  private async verifyFileHash(
    filePath: string,
    expectedSha256: string,
    errorMessage: string,
  ) {
    const actualHash = await RNFS.hash(filePath, 'sha256');
    if (actualHash.toLowerCase() !== expectedSha256.toLowerCase()) {
      throw new Error(errorMessage);
    }
  }

  private async verifyManifestSignature(manifest: HotUpdateManifest) {
    if (!manifest.signature || !hotUpdateConfig.publicKey) {
      return;
    }

    const canonicalPayload = this.canonicalizeManifest(manifest);
    const jsrsasign = getJsrsasign();
    const verifier = new jsrsasign.KJUR.crypto.Signature({
      alg: 'SHA256withRSA',
    });
    verifier.init(hotUpdateConfig.publicKey);
    verifier.updateString(canonicalPayload);

    const isValid = verifier.verify(jsrsasign.b64tohex(manifest.signature));
    if (!isValid) {
      throw new Error('更新包签名校验失败');
    }
  }

  private canonicalizeManifest(manifest: HotUpdateManifest): string {
    const { signature, ...unsignedManifest } = manifest;
    return this.canonicalize(unsignedManifest);
  }

  private canonicalize(value: unknown): string {
    if (value === null || typeof value !== 'object') {
      return JSON.stringify(value);
    }

    if (Array.isArray(value)) {
      return `[${value.map(item => this.canonicalize(item)).join(',')}]`;
    }

    const sortedEntries = Object.entries(value as Record<string, unknown>)
      .filter(([, fieldValue]) => fieldValue !== undefined)
      .sort(([left], [right]) => left.localeCompare(right));

    return `{${sortedEntries
      .map(
        ([key, fieldValue]) =>
          `${JSON.stringify(key)}:${this.canonicalize(fieldValue)}`,
      )
      .join(',')}}`;
  }

  private async activatePackage(installedPackage: InstalledHotUpdatePackage) {
    const state = await this.readState();
    const currentPackageId = state.currentPackageId;

    state.packages[installedPackage.id] = installedPackage;
    state.previousPackageId = currentPackageId;
    state.currentPackageId = installedPackage.id;
    state.pendingPackageId = installedPackage.id;
    state.pendingAttempted = false;

    await this.writeState(state);
    await hotUpdateNativeBridge.setCurrentBundlePath(installedPackage.bundlePath);
  }

  private async rollbackPendingUpdate(packageId: string) {
    const state = await this.readState();
    const previousPackage = state.previousPackageId
      ? state.packages[state.previousPackageId]
      : null;

    state.currentPackageId = previousPackage?.id ?? null;
    state.pendingPackageId = null;
    state.pendingAttempted = false;

    if (previousPackage) {
      await hotUpdateNativeBridge.setCurrentBundlePath(previousPackage.bundlePath);
    } else {
      await hotUpdateNativeBridge.clearCurrentBundlePath();
    }

    await this.writeState(state);
    this.notify(HotUpdateStatus.ROLLBACK);
    await hotUpdateNativeBridge.reloadBundle(previousPackage?.bundlePath ?? null);

    const failedPackage = state.packages[packageId];
    if (failedPackage) {
      await RNFS.unlink(failedPackage.packageDir).catch(() => undefined);
      delete state.packages[packageId];
      await this.writeState(state);
    }
  }

  private async pruneMissingPackages(
    state: HotUpdateState,
  ): Promise<HotUpdateState> {
    const nextState = { ...state, packages: { ...state.packages } };
    const packageEntries = Object.entries(nextState.packages);

    for (const [packageId, hotPackage] of packageEntries) {
      const exists = await RNFS.exists(hotPackage.bundlePath);
      if (exists) {
        continue;
      }

      delete nextState.packages[packageId];
      if (nextState.currentPackageId === packageId) {
        nextState.currentPackageId = null;
      }
      if (nextState.previousPackageId === packageId) {
        nextState.previousPackageId = null;
      }
      if (nextState.pendingPackageId === packageId) {
        nextState.pendingPackageId = null;
        nextState.pendingAttempted = false;
      }
    }

    await this.writeState(nextState);
    return nextState;
  }

  private isVersionSatisfied(currentVersion: string, minVersion: string): boolean {
    return this.compareVersions(currentVersion, minVersion) >= 0;
  }

  private compareVersions(left: string, right: string): number {
    const leftParts = left.split('.').map(part => Number(part) || 0);
    const rightParts = right.split('.').map(part => Number(part) || 0);
    const length = Math.max(leftParts.length, rightParts.length);

    for (let index = 0; index < length; index += 1) {
      const leftValue = leftParts[index] ?? 0;
      const rightValue = rightParts[index] ?? 0;
      if (leftValue > rightValue) {
        return 1;
      }
      if (leftValue < rightValue) {
        return -1;
      }
    }

    return 0;
  }

  private createInstallationId() {
    return `ota-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  }

  private hashToBucket(input: string): number {
    let hash = 0;
    for (let index = 0; index < input.length; index += 1) {
      hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
    }
    return hash % 100;
  }
}

export default new HotUpdateService();
