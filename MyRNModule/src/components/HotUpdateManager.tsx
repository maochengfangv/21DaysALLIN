import React, { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import HotUpdateService from '../services/hot-update/HotUpdateService';
import {
  HotUpdateStatus,
  type HotUpdateProgress,
  type HotUpdateVersionInfo,
} from '../services/hot-update/types';

const defaultVersion: HotUpdateVersionInfo = {
  appVersion: '0.0.0',
  buildNumber: '0',
  currentLabel: '0.0.0',
  description: '未初始化',
  isPending: false,
};

function HotUpdateManager() {
  const [status, setStatus] = useState(HotUpdateStatus.IDLE);
  const [progress, setProgress] = useState<HotUpdateProgress | undefined>();
  const [version, setVersion] = useState<HotUpdateVersionInfo>(defaultVersion);

  useEffect(() => {
    HotUpdateService.getCurrentVersion().then(setVersion).catch(() => undefined);

    const listener = (
      nextStatus: HotUpdateStatus,
      nextProgress?: HotUpdateProgress,
    ) => {
      setStatus(nextStatus);
      setProgress(nextProgress);
      HotUpdateService.getCurrentVersion().then(setVersion).catch(() => undefined);
    };

    HotUpdateService.addListener(listener);
    return () => {
      HotUpdateService.removeListener(listener);
    };
  }, []);

  const statusText = useMemo(() => {
    switch (status) {
      case HotUpdateStatus.DISABLED:
        return '未配置 OTA manifest 地址，当前仅接入基础设施';
      case HotUpdateStatus.CHECKING:
        return '正在检查更新';
      case HotUpdateStatus.UPDATE_AVAILABLE:
        return '发现可用更新';
      case HotUpdateStatus.DOWNLOADING:
        return `正在下载 ${Math.round((progress?.percentage ?? 0) * 100)}%`;
      case HotUpdateStatus.VERIFYING:
        return '正在校验更新包';
      case HotUpdateStatus.READY:
        return version.isPending ? '更新已就绪，重启后生效' : '更新链路已就绪';
      case HotUpdateStatus.ROLLBACK:
        return '检测到异常，已自动回滚到稳定版本';
      case HotUpdateStatus.ERROR:
        return '更新失败，请查看控制台日志';
      case HotUpdateStatus.UP_TO_DATE:
        return '当前已经是最新版本';
      default:
        return '等待检查';
    }
  }, [progress?.percentage, status, version.isPending]);

  const handleManualCheck = async () => {
    try {
      const manifest = await HotUpdateService.checkForUpdate(false);
      if (!manifest) {
        return;
      }

      await HotUpdateService.downloadAndInstall(manifest);
      Alert.alert('热更新已准备完成', '更新已下载，下次启动会自动生效。');
    } catch (error) {
      console.error('[HotUpdate]', error);
    }
  };

  const handleRestart = async () => {
    await HotUpdateService.restartApp();
  };

  const busy =
    status === HotUpdateStatus.CHECKING ||
    status === HotUpdateStatus.DOWNLOADING ||
    status === HotUpdateStatus.VERIFYING ||
    status === HotUpdateStatus.INSTALLING;

  return (
    <View style={styles.card}>
      <Text style={styles.title}>热更新管理</Text>
      <Text style={styles.meta}>原生版本: {version.appVersion} ({version.buildNumber})</Text>
      <Text style={styles.meta}>当前资源包: {version.currentLabel}</Text>
      <Text style={styles.description}>{version.description}</Text>
      <Text style={styles.status}>{statusText}</Text>

      {status === HotUpdateStatus.DOWNLOADING && progress ? (
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${Math.max(progress.percentage * 100, 4)}%` },
            ]}
          />
        </View>
      ) : null}

      <View style={styles.actions}>
        <TouchableOpacity
          style={[styles.button, busy ? styles.buttonDisabled : null]}
          disabled={busy}
          onPress={handleManualCheck}>
          {busy ? (
            <ActivityIndicator color="#FFF" />
          ) : (
            <Text style={styles.buttonText}>检查更新</Text>
          )}
        </TouchableOpacity>

        {version.isPending ? (
          <TouchableOpacity
            style={[styles.button, styles.buttonSecondary]}
            onPress={handleRestart}>
            <Text style={styles.buttonText}>立即重启</Text>
          </TouchableOpacity>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    marginHorizontal: 16,
    marginBottom: 20,
    padding: 16,
    backgroundColor: '#FFF',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowOffset: { width: 0, height: 2 },
    shadowRadius: 8,
    elevation: 2,
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: '#222',
    marginBottom: 8,
  },
  meta: {
    fontSize: 13,
    color: '#666',
    marginBottom: 4,
  },
  description: {
    fontSize: 13,
    color: '#444',
    marginBottom: 10,
  },
  status: {
    fontSize: 14,
    color: '#222',
    marginBottom: 12,
  },
  progressTrack: {
    height: 6,
    backgroundColor: '#E5E7EB',
    borderRadius: 999,
    overflow: 'hidden',
    marginBottom: 12,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#2563EB',
  },
  actions: {
    flexDirection: 'row',
    gap: 12,
  },
  button: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2563EB',
    borderRadius: 8,
    minHeight: 44,
    paddingHorizontal: 12,
  },
  buttonSecondary: {
    backgroundColor: '#059669',
  },
  buttonDisabled: {
    opacity: 0.65,
  },
  buttonText: {
    color: '#FFF',
    fontSize: 15,
    fontWeight: '600',
  },
});

export default HotUpdateManager;
