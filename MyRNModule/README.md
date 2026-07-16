# MyRNModule — React Native OTA 热更新 + TurboModule/Fabric Demo

## 项目概述

基于 **React Native 0.86.0 New Architecture**，核心展示 **生产级 OTA 热更新基础设施** — 覆盖 Manifest 驱动更新检查、ZIP 下载解压、SHA256 完整性校验、RSA-SHA256 签名验证、灰度发布百分比命中、首次启动失败自动回滚、installMode（`on_next_restart` / `immediate`）的完整链路。同时包含 **CounterTurboModule**（Codegen 双端实现）和 **NativeColoredView**（Fabric 组件）。

## 项目结构

```
MyRNModule/
├── src/
│   ├── services/hot-update/
│   │   ├── HotUpdateService.ts      # OTA 核心引擎（~550 行）：状态机 + 下载/校验/激活/回滚
│   │   ├── nativeBridge.ts          # JS-Native 桥接层（含 fallback 容错）
│   │   └── types.ts                 # 全部 TypeScript 类型定义
│   ├── config/
│   │   └── hotUpdate.ts             # OTA 配置（manifestURL/channel/publicKey/installMode）
│   └── components/
│       └── HotUpdateManager.tsx      # OTA UI 面板（状态/进度/手动检查/重启）
├── ios/MyRNModule/
│   ├── AppDelegate.swift            # Bundle URL 决策：DEBUG → Metro / RELEASE → OTA优先 或 main.jsbundle
│   ├── HotUpdateBridge.swift        # NativeModule：6 个 OTA 原生方法 + Bundle Reload
│   ├── HotUpdateBridge.m            # ObjC 桥接文件（RCT_EXTERN_MODULE）
│   └── HotUpdateBundleStore.swift   # UserDefaults 持久化 Bundle 路径
├── android/.../myrnmodule/
│   ├── HotUpdateBridgeModule.kt     # Android 侧 OTA Native Bridge
│   ├── HotUpdateBundleStore.kt      # SharedPreferences 持久化
│   ├── CounterTurboModule.kt        # TurboModule（extends Codegen 生成 Spec）
│   └── ColoredViewManager.kt        # Fabric 组件 ViewManager
├── specs/
│   ├── NativeCounter.ts             # TurboModule TS Spec
│   └── NativeColoredView.ts         # Fabric Component TS Spec
├── scripts/
│   ├── ota-release.sh               # 一键发布：bundle 打包 → ZIP 压缩 → Manifest 生成
│   └── create-ota-manifest.mjs      # Manifest 生成器：SHA256 + RSA-SHA256 签名 + canonicalize
├── docs/
│   └── OTA_SETUP.md                 # OTA 完整接入文档（含 iOS 热修复技术细节 + Apple 审核备注）
└── package.json                     # RN 0.86.0 / codegenConfig: MyRNAppSpecs
```

---

## 技术要点

### 一、OTA 热更新完整链路

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OTA 发布流程                                  │
│                                                                     │
│  ota-release.sh                                                     │
│    ├── npx react-native bundle (--dev false)                        │
│    ├── zip bundle + assets → package.zip                            │
│    └── create-ota-manifest.mjs                                       │
│          ├── SHA256(package.zip) → packageSha256                    │
│          ├── SHA256(bundle)     → bundleSha256                      │
│          ├── canonicalize + RSA-SHA256 签名 → signature             │
│          └── 输出 manifest.json                                     │
│                  │                                                   │
│                  ▼ (上传 CDN)                                       │
│   ┌──────────────────────────────────────────────┐                  │
│   │             OTA 客户端流程                     │                  │
│   │                                              │                  │
│   │  initialize()                                │                  │
│   │    ├── ensureStorage (hot-updates/ 目录)      │                  │
│   │    ├── installationId 生成 (灰度 hash key)    │                  │
│   │    ├── pruneMissingPackages (清理已删除的包)   │                  │
│   │    └── 检查 pendingPackageId                  │                  │
│   │          ├── pendingAttempted = true?         │                  │
│   │          │   → rollbackPendingUpdate()        │  ← 自动回滚     │
│   │          │   → reloadBundle(previous)         │                  │
│   │          └── 首次启动                         │                  │
│   │              → pendingAttempted = true        │  ← 标记"待确认"  │
│   │                                              │                  │
│   │  App 成功启动 → markApplicationReady()        │                  │
│   │    → 清除 pendingPackageId                    │  ← 确认稳定     │
│   └──────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 二、灰度发布（Rollout）

```typescript
// 百分比命中算法：installationId:manifestId 的 hash → bucket (0-99)
private async isRolloutMatched(manifest: HotUpdateManifest): Promise<boolean> {
  const rollout = manifest.rollout ?? 100;
  if (rollout >= 100) return true;

  const state = await this.readState();
  const bucket = this.hashToBucket(`${state.installationId}:${manifest.id}`);
  return bucket < rollout;  // rollout=20 → 仅前 20% 设备命中
}
```

- `installationId` 在首次初始化时生成（`ota-{timestamp}-{random}`），持久化在 `state.json`
- `hashToBucket` 使用 DJB2-like 哈希，确保同一设备始终命中同一分组

### 三、双重 SHA256 校验 + RSA-SHA256 签名

```typescript
// 第一步：校验 ZIP 包完整性
await this.verifyFileHash(zipFilePath, manifest.packageSha256, '更新包哈希不匹配');

// 第二步：解压后校验 bundle 文件
await unzip(zipFilePath, stagingDir);
await this.verifyFileHash(bundlePath, manifest.bundleSha256, 'bundle 哈希不匹配');

// 第三步：签名验证（RSA-SHA256，可选）
await this.verifyManifestSignature(manifest);
```

**签名验证**使用 `canonicalize` 算法：移除 `signature` 字段 → 对剩余字段做字典序排序 → 递归 JSON 序列化 → `SHA256withRSA` 签名验证。JS 侧 `jsrsasign` 惰性加载（避免 Metro 打包时 Node.js crypto 依赖失败）。

### 四、自动回滚机制

```
状态机：
  IDLE → (安装完成) → pendingPackageId = X, pendingAttempted = false
                     → (reload 后) → pendingAttempted = true
                        ├── App 正常启动 → markApplicationReady() → 清除 pending
                        └── App 崩溃/再次启动
                            → initialize() 发现 pendingAttempted = true
                            → rollbackPendingUpdate()
                              ├── setCurrentBundlePath(previous)
                              ├── clearCurrentBundlePath() (若无 previous)
                              ├── notify(ROLLBACK)
                              ├── reloadBundle(previous)
                              └── 清理失败包的本地文件
```

- 两段确认机制确保"只有真正成功运行的包才会替代旧包"
- 回滚时自动删除失败的 bundle 目录（`RNFS.unlink`）

### 五、installMode 双模式

| Mode | `on_next_restart` | `immediate` |
|------|-------------------|-------------|
| 下载完成后 | `notify(READY)`，等待下次启动 | `reloadBundle()` 立即切换 |
| 适用场景 | 生产环境推荐（无感知） | 紧急修复需要即时生效 |
| App 审核 | 安全，不改变审核版本行为 | 安全，仅替换 JS bundle |

### 六、iOS Bundle 切换核心机制

```swift
// 1. 设置新的 bundle URL 到 RN 运行时
RCTReloadCommandSetBundleURL(nextBundleURL)

// 2. 主线程触发 reload，RN 从步骤 1 的 URL 加载新 bundle
DispatchQueue.main.async {
    RCTTriggerReloadCommandListeners("Hot update bundle reload")
}
```

两步必须按序执行。Android 侧通过 `ReactHost.jsBundleFilePath` + `reactHost.reload()` 实现。

**Bundle URL 决策链**（[AppDelegate.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/MyRNModule/AppDelegate.swift)）：
```
DEBUG → Metro 开发服务器
RELEASE → HotUpdateBundleStore.currentBundleURL()  // OTA 路径（优先）
        ?? Bundle.main.url(forResource: "main", ...) // App 内置 bundle（兜底）
```

### 七、Native Bridge 三层架构

```
JS 层 (HotUpdateService.ts)
  → nativeBridge.ts (NativeModules.HotUpdateBridge + fallback)
    ├── iOS:
    │   HotUpdateBridge.m (RCT_EXTERN_MODULE, ObjC 桥接声明)
    │   HotUpdateBridge.swift (6 个 Native Method 实现)
    │   HotUpdateBundleStore.swift (UserDefaults CRUD)
    │
    └── Android:
        HotUpdateBridgeModule.kt (ReactContextBaseJavaModule)
        HotUpdateBundleStore.kt (SharedPreferences)
```

`nativeBridge.ts` 提供 **fallback 机制**：当 Native Module 未注册时（测试环境/未完整构建），返回空值默认行为，不会导致 JS 崩溃。

### 八、OTA 发布流程

```bash
bash ./scripts/ota-release.sh android production 1.0.0 https://cdn.example.com/ota "修复首页白屏"

# 环境变量可选参数：
OTA_LABEL=v20260715123000           # 自定义版本标签
OTA_ROLLOUT=20                      # 灰度比例 20%
OTA_ENTRY_FILE=index.js             # 自定义入口文件
OTA_PRIVATE_KEY_PATH=./private.pem  # RSA 私钥路径
OTA_MIN_NATIVE_VERSION=1.0.0        # 最低原生版本要求
OTA_MANDATORY=true                  # 强制更新
OTA_PACKAGE_TYPE=full               # 全量/补丁包
```

产物输出：
```
build/ota/android/1.0.0/
├── package.zip       # bundle + assets 压缩包
├── manifest.json     # id / label / sha256 / signature / rollout 等元数据
└── package/
    ├── index.android.bundle
    └── assets/...
```

### 九、TurboModule + Fabric Component

**CounterTurboModule**：简单计数器（`getValue/increment/decrement/reset`），双端 Codegen 实现，iOS `RCT_EXPORT_MODULE(NativeCounter)` + Android `@ReactModule(name = "NativeCounter")`

**NativeColoredView**：Fabric 组件，类比 MyRNApp01 的 InterviewFabricCard，Codegen 驱动 prop 绑定

**codegenConfig（package.json）**：
```json
{
  "codegenConfig": {
    "name": "MyRNAppSpecs",
    "type": "all",
    "jsSrcsDir": "specs",
    "android": { "javaPackageName": "com.myrnmodule" },
    "ios": {
      "componentProvider": { "NativeColoredView": "NativeColoredView" },
      "modulesProvider": { "NativeCounter": "CounterTurboModule" }
    }
  }
}
```

### 十、Apple 审核合规

详见 [docs/OTA_SETUP.md](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/docs/OTA_SETUP.md)：
- 本方案仅替换 JS bundle（通过 JavaScriptCore 执行），符合 App Store Review Guideline 2.5.2
- `react-native-zip-archive` 的 `SSZipArchive` 依赖不含私有 API
- 首次提交建议在 App Review Information Notes 中说明热更新用途

---

## 运行方式

```bash
cd MyRNModule

# iOS
cd ios && pod install && cd ..
npx react-native run-ios

# Android
npx react-native run-android

# OTA 发布
bash ./scripts/ota-release.sh android production 1.0.0 https://cdn.example.com/ota
```

- OTA 功能需先配置 `src/config/hotUpdate.ts` 中的 `manifestURL` 和 `publicKey`
- Metro 需已启动（`npx react-native start`）

## 技术标签

`React Native` `OTA 热更新` `Manifest 驱动` `SHA256` `RSA-SHA256` `灰度发布` `自动回滚` `TurboModule` `Fabric` `Codegen` `RCTReloadCommandSetBundleURL` `RCTTriggerReloadCommandListeners` `UserDefaults` `SharedPreferences` `react-native-fs` `react-native-zip-archive` `Apple 审核合规`
