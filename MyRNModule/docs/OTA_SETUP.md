# OTA 接入说明

## 当前实现

项目已接入一套兼容 React Native 0.86 New Architecture 的自定义 OTA 基础设施，核心能力包括：

- 应用启动检查本地已安装 bundle，并优先加载 OTA bundle
- Manifest 驱动的更新检查
- ZIP 更新包下载、解压与 SHA256 完整性校验
- 可选 RSA-SHA256 签名校验
- 多版本元数据管理
- 首次启动失败后的自动回滚
- 灰度发布百分比命中

## 需要补的配置

编辑 [src/config/hotUpdate.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/config/hotUpdate.ts)：

```ts
export const hotUpdateConfig = {
  enabled: true,
  manifestURL: 'https://cdn.example.com/ota/android/latest/manifest.json',
  channel: 'production',
  publicKey: `-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----`,
  requestTimeoutMs: 8000,
  autoCheckOnLaunch: true,
  installMode: 'on_next_restart',
};
```

建议：

- Android / iOS 分别提供各自 manifest URL
- `publicKey` 对应发布时使用的私钥
- 生产环境默认 `installMode: 'on_next_restart'`

## Manifest 格式

```json
{
  "id": "android-production-1.0.0-v20260715123000",
  "label": "v20260715123000",
  "platform": "android",
  "channel": "production",
  "version": "1.0.0",
  "packageUrl": "https://cdn.example.com/ota/android/1.0.0/package.zip",
  "packageSha256": "zip-sha256",
  "bundleFile": "index.android.bundle",
  "bundleSha256": "bundle-sha256",
  "description": "修复首页白屏",
  "mandatory": false,
  "rollout": 20,
  "minNativeVersion": "1.0.0",
  "packageType": "full",
  "signatureAlgorithm": "RSA-SHA256",
  "signature": "base64-signature"
}
```

## 打包与发布

1. 生成 OTA 产物：

```bash
cd /Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule
bash ./scripts/ota-release.sh android production 1.0.0 https://cdn.example.com/ota "修复首页白屏"
```

2. 产物位于：

- `build/ota/<platform>/<version>/package.zip`
- `build/ota/<platform>/<version>/manifest.json`

3. 上传到 CDN 或对象存储后，将 manifest 地址填回 `src/config/hotUpdate.ts`

## 回滚机制

- 安装新包后，状态会被标记为 `pending`
- 新包首次启动时，状态会被标记为“待确认”
- 若应用在确认前再次启动，系统会判定上次新包未稳定运行，并自动回滚到上一稳定包
- 若首次启动成功，`App.tsx` 会调用 `markApplicationReady()` 清除待确认状态

## iOS 端热修复技术要点

### Bundle 加载流程

iOS 端 bundle 加载入口在 [AppDelegate.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/MyRNModule/AppDelegate.swift) 中：

```swift
class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    HotUpdateBundleStore.currentBundleURL() ?? Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
```

- **DEBUG 模式**：使用 Metro 开发服务器，不从本地加载 bundle
- **生产模式**：优先读取 `HotUpdateBundleStore` 中记录的 OTA bundle 路径；若路径不存在或文件已丢失，回退到 App 内置的 `main.jsbundle`

### Bundle 持久化存储

[HotUpdateBundleStore.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/MyRNModule/HotUpdateBundleStore.swift) 基于 `UserDefaults` 实现，核心逻辑：

- `setCurrentBundlePath(_:)`：将 OTA bundle 的本地绝对路径写入 UserDefaults
- `currentBundlePath()`：读取路径，并验证文件是否真实存在；若文件缺失则自动清除记录，避免加载不存在 bundle 导致白屏
- `clearCurrentBundlePath()`：清除记录，使下次启动回到内置 bundle

### Swift / ObjC 原生桥接

[HotUpdateBridge.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/MyRNModule/HotUpdateBridge.swift) 将 `HotUpdateBridge` 暴露给 React Native 的 NativeModules 系统。为保证 RN 0.86 能发现模块，必须通过一个 ObjC 桥接文件 [HotUpdateBridge.m](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/MyRNModule/HotUpdateBridge.m) 声明每个 Native Method：

```objc
@interface RCT_EXTERN_MODULE(HotUpdateBridge, NSObject)
RCT_EXTERN_METHOD(getCurrentBundlePath:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
// ... 其余方法
@end
```

暴露给 JS 的方法：
| 方法 | 用途 |
| --- | --- |
| `getCurrentBundlePath` | 获取当前 OTA bundle 路径 |
| `setCurrentBundlePath` | 设置 OTA bundle 路径（安装完成时调用） |
| `clearCurrentBundlePath` | 清除路径（回滚时调用） |
| `getEmbeddedBundlePath` | 获取 App 内置的 `main.jsbundle` 路径 |
| `reloadBundle` | 切换 bundle 并触发 reload（核心热修复方法） |
| `getAppVersion` / `getBuildNumber` | 读取 `Info.plist` 中的版本号 |

### Bundle 切换与 Reload 机制

这是 iOS 端热修复最关键的步骤，在 `HotUpdateBridge.reloadBundle(_:resolver:rejecter:)` 中实现：

```swift
// 1. 设置新的 bundle URL
RCTReloadCommandSetBundleURL(nextBundleURL)

// 2. 在主线程触发 reload
DispatchQueue.main.async {
  RCTTriggerReloadCommandListeners("Hot update bundle reload")
}
```

两步必须按顺序执行：
1. `RCTReloadCommandSetBundleURL` — 将 nextBundleURL 注入 RN 运行时，下次 reload 时优先加载
2. `RCTTriggerReloadCommandListeners` — 实际触发 React Native 重新加载，此时 RN 会从步骤 1 设置的 URL 读取新 bundle

**与 Android 的区别**：Android 侧通过 `ReactHost.getDefaultReactHost()` 的 `jsBundleFilePath` 参数 + `reactHost.reload()` 实现，而 iOS 使用 `RCTReloadCommandSetBundleURL` 全局命令 + `RCTTriggerReloadCommandListeners` 触发。

### OTA 文件存储路径

JS 层在 [HotUpdateService.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/services/hot-update/HotUpdateService.ts) 中定义：

```ts
const OTA_ROOT_DIR = `${RNFS.DocumentDirectoryPath}/hot-updates`;
```

在 iOS 上，`RNFS.DocumentDirectoryPath` 对应沙盒内的 `Documents` 目录（`NSDocumentDirectory`），该目录不会被 App 更新覆盖，用户可通过 iTunes 文件共享访问。

目录结构示例：
```
Documents/hot-updates/
├── downloads/          # 下载中的 ZIP 包
├── packages/           # 已安装的各版本 bundle
│   └── <package-id>/
│       └── index.ios.bundle
└── state.json          # OTA 状态文件
```

### Podfile 平台版本

[Podfile](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/Podfile) 中 `platform :ios, '15.5'` 是最低 iOS 部署目标。该版本是基于 `react-native-zip-archive` 的依赖 `SSZipArchive` 要求确定的：低于 15.5 会导致 CocoaPods 平台版本不匹配错误。

### Apple 审核注意事项

1. **必须说明热更新的用途**：Apple 允许 JavaScript-based 的热更新（通过 WebKit/JavaScriptCore），但禁止动态下发编译后的原生代码。本方案仅替换 JS bundle，符合 App Store Review Guideline 2.5.2。
2. **更新内容应保持与审核版本一致的功能**：避免通过 OTA 解锁审核时未展示的功能，否则可能被判定为 4.2.2（Minimum Functionality）。
3. **首次提交建议附带**：App Review Information Notes 中注明“使用基于 JavaScriptCore 的热更新以修复紧急线上问题”。
4. **`react-native-zip-archive` 的 `SSZipArchive` 依赖**：该库为 C 语言编写的 ZIP 解压库，不涉及私有 API 调用，安全合规。
