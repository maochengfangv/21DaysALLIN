# MyRNModule — React Native 新架构 · 业务卡片 + OTA 热更新

## 项目定位

面向**棕地集成**的 RN 业务模块：封装可复用的卡片/列表组件，提供独立的 CocoaPods 桥接库（`RNBridgePodspec`），供 iOS 原生壳 `IOSRNContainer` 以静态库方式引入。覆盖：

- **RN 新架构（0.86.0）**：TurboModule（JSI 零拷贝）+ Fabric（C++ Shadow Tree 同步渲染）
- **双端 Codegen**：`specs/*.ts` → iOS ObjC++ 协议 / Android Kotlin 基类
- **生产级 OTA**：Manifest 驱动 + SHA256/RSA-SHA256 + 自动回滚 + 灰度
- **模块化解耦**：`BusinessCardList` 独立注册，可与 `MyRNModule` 主入口分别加载

## 目录结构

```
MyRNModule/
├── specs/
│   ├── NativeCounter.ts                 # Demo TurboModule 规格
│   ├── NativeColoredView.ts             # Demo Fabric 组件规格
│   ├── NativeBusinessCardBridge.ts      # 【新增】业务卡片 TurboModule 规格
│   └── NativeBusinessCardView.ts        # 【新增】业务卡片 Fabric 组件规格
├── src/
│   ├── components/cards/
│   │   ├── types.ts                     # 卡片/操作/回调 全量类型
│   │   ├── BusinessCard.tsx             # 卡片单元：iOS 0 号卡优先走 Fabric，其余走 JS 兜底
│   │   └── CardListScreen.tsx           # 卡片列表：TurboModule 初始数据 + PullRefresh
│   ├── services/hot-update/
│   │   ├── HotUpdateService.ts          # OTA 状态机引擎
│   │   └── types.ts
│   └── config/hotUpdate.ts
├── ios/
│   ├── BridgePodspec/
│   │   ├── RNBridgePodspec.podspec      # 【新增】CocoaPods 发布清单
│   │   └── Classes/
│   │       ├── HotUpdateBundleStore.swift
│   │       ├── HotUpdateBridge.swift
│   │       ├── RNBridgeManager.swift     # Bridge 预加载 + Bundle 源切换（三态）
│   │       ├── RNCardViewController.swift# 通用 RN 卡片 VC + delegate
│   │       ├── BusinessCardBridgeTurboModule.swift
│   │       ├── BusinessCardFabricViewManager.swift
│   │       └── RCTBusinessCardView.swift
├── index.js                             # 【改造】注册 BusinessCardList 独立模块
├── app.json                             # 【改造】声明 modules 数组
└── package.json                         # 【改造】codegenConfig 加入 BusinessCard* 提供器
```

## AppRegistry 双模块注册

```javascript
// index.js
AppRegistry.registerComponent('MyRNModule', () => App);            // 主入口：完整 Demo
AppRegistry.registerComponent('BusinessCardList', () => CardListScreen); // 独立模块：卡片列表
```

原生侧通过 `moduleName` 分别加载：

```swift
// 完整 Demo
RCTRootView(bridge: bridge, moduleName: "MyRNModule", initialProperties: [...])

// 仅卡片列表
RCTRootView(bridge: bridge, moduleName: "BusinessCardList", initialProperties: [
    "title": "发现 · 业务卡片",
    "subtitle": "Native 注入 + Fabric 渲染 + 热更新",
    "enablePullRefresh": true
])
```

## 卡片数据与回调协议

### JS 侧类型（`types.ts`）
```typescript
export interface BusinessCardData {
  cardId: string;
  cardType: 0 | 1 | 2 | 3;     // 0 = Fabric 原生渲染，1~3 = JS 渲染
  title: string;
  subtitle?: string;
  coverUrl?: string;
  tag?: string;
  timestamp?: number;          // ms
}

export interface CardAction {
  id: string;
  title: string;
  actionType: 0 | 1 | 2 | 3;  // 0=跳转 1=收藏 2=分享 3=点赞
}

// 回调：JS → TurboModule → Native
BusinessCardBridge.onCardPress(cardId)
BusinessCardBridge.onActionPress(cardId, actionId, actionType)
BusinessCardBridge.onExposure(cardId, timestamp)
BusinessCardBridge.getInitialCards(): Promise<string>  // JSON String
```

### Fabric 降维策略

`BusinessCard.tsx` 针对 iOS 平台 + `cardType=0` 组合优先渲染 `BusinessCardFabricView`（C++ Props 同步绑定，无异步 Bridge 序列化开销），其余场景自动降级为 JS 实现保证可用性。

## RNBridgeManager — 桥预加载 + 三源 Bundle 切换

```swift
@objc public enum RNBundleSource: Int {
    case embedded = 0     // App 内置 main.jsbundle
    case hotUpdate = 1    // OTA 下载目录
    case remoteDebug = 2  // Metro 开发服务器
}

@objc public enum RNBridgePreloadPolicy: Int {
    case onDemand = 0                  // 按需懒加载
    case onAppDidFinishLaunching = 1   // App 启动即预加载
    case onHomeDidAppear = 2           // 首页出现后预加载
}
```

### Bundle URL 决策链

```
DEBUG:
  Info.plist.RNMetroServerIP → Metro URL
  → RCTBundleURLProvider 兜底（localhost:8081）

RELEASE:
  HotUpdateBundleStore.currentBundlePath()  // OTA 已下载 → 优先
  → Bundle.main.url("main.jsbundle")        // 内置兜底
```

### 运行时切换 Bundle 源

```swift
// 切回内置
RNBridgeManager.shared.switchBundle(to: .embedded)

// 切到 OTA
RNBridgeManager.shared.switchBundle(to: .hotUpdate)

// 指定自定义路径
RNBridgeManager.shared.switchBundle(to: .hotUpdate,
                                    customPath: "/Documents/hot-updates/packages/xxx/main.jsbundle")
```

切换后调用 `RCTReloadCommandSetBundleURL()` + `RCTTriggerReloadCommandListeners()`，所有后续 `RCTRootView` 创建会使用新 bundle。

## RNBridgePodspec 集成（给原生宿主工程）

### Podfile

```ruby
# 解析 MyRNModule 的 react_native_pods.rb
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', File.expand_path('../MyRNModule', __dir__)]).strip

ENV['RCT_NEW_ARCH_ENABLED'] = '1'
ENV['USE_FRAMEWORKS'] = 'static'

target 'YourNativeApp' do
  rn_app_path = File.expand_path('../MyRNModule', __dir__)
  rn_node_modules_path = File.join(rn_app_path, 'node_modules')
  rn_react_native_path = File.join(rn_node_modules_path, 'react-native')

  use_react_native!(
    :path => rn_react_native_path,
    :app_path => rn_app_path
  )
  pod 'react-native-safe-area-context', :path => File.join(rn_node_modules_path, 'react-native-safe-area-context')

  # 引入业务 Pod 库
  pod 'RNBridgePodspec', :path => File.join(rn_app_path, 'ios/BridgePodspec')
end
```

### 原生调用示例

```swift
import RNBridgePodspec

// 1. App 启动预加载
func application(_ app:, didFinishLaunchingWithOptions opts:) -> Bool {
    RNBridgeManager.shared.preloadPolicy = .onAppDidFinishLaunching
    RNBridgeManager.shared.preloadIfNeeded(launchOptions: opts)
    return true
}

// 2. 打开卡片列表
let cardsVC = RNCardViewController(
    moduleName: "BusinessCardList",
    initialProperties: ["title": "业务卡片", "enablePullRefresh": true],
    initialCardsPayload: jsonString
)
cardsVC.onCardPress = { cardId in /* 路由跳转 */ }
cardsVC.onActionPress = { cardId, actionId, type in /* 业务操作 */ }
cardsVC.onExposure = { cardId, ts in /* 曝光埋点 */ }
navigationController.pushViewController(cardsVC, animated: true)
```

## OTA 热更新使用流程

### 1. 配置参数（`src/config/hotUpdate.ts`）

```typescript
export const hotUpdateConfig: HotUpdateConfig = {
  enabled: true,
  manifestURL: 'https://cdn.example.com/ota/manifest.json',
  channel: 'production',
  publicKey: `-----BEGIN PUBLIC KEY-----\nMIIB...\n-----END PUBLIC KEY-----`,
  requestTimeoutMs: 8000,
  autoCheckOnLaunch: true,
  installMode: 'on_next_restart'   // 或 'immediate'
};
```

### 2. 启动流程

```typescript
// App.tsx
useEffect(() => {
  (async () => {
    await HotUpdateService.initialize();
    await HotUpdateService.markApplicationReady();   // 确认成功启动（清除 pending 标记）
    await HotUpdateService.autoCheckForUpdate();     // 自动检查+下载+激活
  })();
}, []);
```

### 3. 发布 OTA 包

```bash
cd MyRNModule
bash ./scripts/ota-release.sh ios production 2026.08.06 \
  https://cdn.example.com/ota \
  "卡片模块：新增 Fabric 原生视图支持"

# 环境变量：
#   OTA_ROLLOUT=20           灰度 20%
#   OTA_MANDATORY=true       强制更新
#   OTA_MIN_NATIVE_VERSION=1.2.0
```

### 4. 自动回滚触发条件

- 新 bundle 安装完成后，标记 `pendingPackageId` + `pendingAttempted=false`
- 下次启动：`pendingAttempted=true`
- 如果 App **成功启动** 并调用 `markApplicationReady()`：清除 pending，安装确认成功
- 如果 App **崩溃或未到 ready 就重启**：`initialize()` 检测到 `pendingAttempted=true`，触发 `rollbackPendingUpdate()` → 切回 previous 包 + 清理失败包文件

## 运行与调试

```bash
# === 首次构建 ===
cd MyRNModule
npm install                    # 或 npm ci
cd ios && pod install && cd .. # Codegen 会从 specs/ 生成 MyRNAppSpecs

# === 开发模式 ===
npx react-native start         # 启动 Metro（另一终端）
cd ios
pod install                    # 首次或增删 Native Module 后
xed -b .                       # 打开 xcworkspace，Cmd+R 运行

# === 打 OTA 包 ===
bash ./scripts/ota-release.sh ios production 2026.08.06.1 https://cdn.example.com/ota

# === 验证 Codegen 生成结果 ===
# 产物位于：ios/Pods/Headers/Public/ReactCodegen/MyRNAppSpecs
# 包含：NativeCounterSpec / BusinessCardBridgeSpec / NativeColoredViewComponentDescriptor 等
```

## 关键文件索引

| 职责 | 文件 |
|------|------|
| 卡片 TS 类型 | [types.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/components/cards/types.ts) |
| 卡片单元组件（含 Fabric 降维） | [BusinessCard.tsx](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/components/cards/BusinessCard.tsx) |
| 卡片列表页（TurboModule 取初始数据） | [CardListScreen.tsx](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/components/cards/CardListScreen.tsx) |
| BusinessCardBridge TurboModule 规格 | [NativeBusinessCardBridge.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/specs/NativeBusinessCardBridge.ts) |
| BusinessCardFabricView 规格 | [NativeBusinessCardView.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/specs/NativeBusinessCardView.ts) |
| 模块注册（双入口） | [index.js](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/index.js) |
| OTA 状态机引擎 | [HotUpdateService.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/src/services/hot-update/HotUpdateService.ts) |
| Bridge 预加载 & Bundle 切换 | [RNBridgeManager.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/BridgePodspec/Classes/RNBridgeManager.swift) |
| 通用 RN 卡片 VC | [RNCardViewController.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/BridgePodspec/Classes/RNCardViewController.swift) |
| CocoaPods 发布清单 | [RNBridgePodspec.podspec](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/ios/BridgePodspec/RNBridgePodspec.podspec) |
