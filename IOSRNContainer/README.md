# IOSRNContainer — iOS 原生壳 + RN 新架构棕地集成 · 控制台

## 项目定位

iOS 原生 App（棕地）侧集成 React Native 0.86.0 新架构的**宿主工程**。核心能力：

- **RCTReactNativeFactory** 生命周期管理 + **RNBridgeManager** 桥预加载（启动性能优化）
- **三态 Bundle 源切换**：`embedded（内置）` ↔ `hotUpdate（OTA）` ↔ `remoteDebug（Metro）`
- **双模块独立加载**：`MyRNModule`（完整 Demo） / `BusinessCardList`（仅卡片列表）
- **TurboModule + Fabric Codegen** 双端绑定：业务卡片回调走 JSI 零拷贝、C++ Props 同步
- **控制台首页**：5 个入口 + 实时状态面板，可视化验证 OTA 链路、Fabric 渲染、原生↔JS 回调

## 目录结构

```
IOSRNContainer/
├── IOSRNContainer/
│   ├── AppDelegate.swift                    # bootstrap ReactNativeHost + RNBridgeManager
│   ├── SceneDelegate.swift
│   ├── ViewController.swift                 # 【重写】RN 控制台：5 入口 + 状态面板
│   ├── ReactNativeHost.swift                # 【重写】Factory + RNBridgeManager 双适配
│   ├── ReactNativeViewController.swift      # 【重写】支持 onCardPress/onActionPress/onExposure
│   ├── RNBusinessEventEmitter.h/.m          # 原生 → JS 事件总线（固定 Event + callbackId 路由）
│   ├── RNBusinessConstants.h/.m/.swift      # 业务常量：callbackId、模块名
│   └── Info.plist
├── IOSRNModule/                             # 【扩展】业务 Native Module 实现
│   ├── CodegenHeaders/
│   │   └── MyRNAppSpecs.h                   # Codegen 产物（pod install 自动生成）
│   ├── CounterTurboModule.h/.mm             # Demo TurboModule：NativeCounterSpec
│   ├── NativeColoredView.h/.mm              # Demo Fabric：RCTViewComponentView
│   ├── BusinessCardBridgeTurboModule.h/.mm  # 【新增】业务卡片 TurboModule + JSI 绑定
│   └── BusinessCardFabricView.h/.mm         # 【新增】业务卡片 Fabric + C++ Props/EventEmitter
├── Podfile                                  # 【改造】引入 pod 'RNBridgePodspec'
└── Podfile.lock
```

## Podfile 关键配置

```ruby
# 1. 从 MyRNModule 解析 react_native_pods.rb
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', File.expand_path('../MyRNModule', __dir__)]).strip

# 2. 新架构显式开关
ENV['RCT_NEW_ARCH_ENABLED'] = '1'
ENV['USE_FRAMEWORKS'] = 'static'

target 'IOSRNContainer' do
  rn_app_path = File.expand_path('../MyRNModule', __dir__)
  rn_node_modules_path = File.join(rn_app_path, 'node_modules')
  rn_react_native_path = File.join(rn_node_modules_path, 'react-native')

  use_react_native!(
    :path => rn_react_native_path,
    :app_path => rn_app_path            # Codegen 从该路径读取 specs/*.ts
  )
  pod 'react-native-safe-area-context', :path => File.join(rn_node_modules_path, 'react-native-safe-area-context')

  # 3. 引入 RN 桥接 Pod
  pod 'RNBridgePodspec', :path => File.join(rn_app_path, 'ios/BridgePodspec')
end
```

## 首页控制台 5 入口说明

| 按钮 | 功能 | 核心技术点 |
|------|------|-----------|
| 📱 打开 RN 主页面 | 加载 `moduleName: "MyRNModule"`，完整 Demo（热更新面板/TurboModule/Fabric） | `RCTReactNativeFactory.rootViewFactory.view()` |
| 🎴 打开 RN 卡片列表 | 加载 `moduleName: "BusinessCardList"`，原生注入 mock 卡片数据并绑定回调 | `BusinessCardBridgeTurboModule.setInitialCardsPayload()` + JS 侧 `getInitialCards()` |
| 📦 切换内置 Bundle | 调用 `RNBridgeManager.switchBundle(to: .embedded)` | `RCTReloadCommandSetBundleURL()` + `RCTTriggerReloadCommandListeners()` |
| 🔥 切换热更 Bundle | 调用 `RNBridgeManager.switchBundle(to: .hotUpdate)`，无 OTA 包时自动 fallback | `HotUpdateBundleStore.currentBundlePath()` 校验文件存在 |
| 🔄 重新加载 Bundle | 触发运行时重载，下一次打开 RN 页面用最新源 | `NotificationCenter` + Bridge 重建流程 |

### 状态面板

控制台底部实时展示：
- 内置 `main.jsbundle` 是否存在（Debug 模式通常从 Metro 拉取，显示 `⚠️ 不存在` 属正常）
- 当前 Bundle 源：`embedded` / `hotUpdate` / `remoteDebug`
- Bundle 路径 + Bridge Ready / Valid 状态

## 原生 ↔ JS 回调链路（业务卡片场景）

### 数据流方向一：原生 → JS（初始卡片）

```
ViewController.openCardListPage()
  └── BusinessCardBridgeTurboModule.setInitialCardsPayload(jsonString)
        └── JS CardListScreen.componentDidMount
              └── BusinessCardBridge.getInitialCards()  // Promise<String>
                    └── TurboModule → JSI → 原生 → JSON.parse → 渲染
```

### 数据流方向二：JS → 原生（用户操作）

```
JS BusinessCard.onPress(cardId)
  └── BusinessCardBridge.onCardPress(cardId)
        └── JSI → ObjCTurboModule → BusinessCardBridgeTurboModule.onCardPress
              └── 静态 block 回调
                    └── ReactNativeViewController.bindBusinessCardCallbacks
                          └── ViewController { showAlert / 路由跳转 / 埋点 }
```

### 三种回调协议

```swift
ReactNativeViewController.cardVC.onCardPress = { cardId in
    // 整张卡片点击：路由跳转
}
cardVC.onActionPress = { cardId, actionId, actionType in
    // 按钮操作：actionType 0=跳转 1=收藏 2=分享 3=点赞
}
cardVC.onExposure = { cardId, timestamp in
    // 曝光埋点：0.3s 延迟去抖，防止快速滑过误报
}
```

## Bundle 决策链 & 热更新生效条件

`ReactNativeHost.ContainerReactNativeDelegate.bundleURL()` 的决策优先级：

```
┌─ DEBUG 模式 ──────────────────────────────────────┐
│ 1. Info.plist["RNMetroServerIP"] → 自定义 Metro IP │
│ 2. RCTBundleURLProvider → localhost:8081 兜底       │
└────────────────────────────────────────────────────┘
┌─ RELEASE 模式 ─────────────────────────────────────────────┐
│ 1. RNBridgeManager.hotUpdateBundleURL()  // OTA 已下载优先   │
│ 2. Bundle.main.url("main.jsbundle")     // 内置兜底        │
└─────────────────────────────────────────────────────────────┘
```

**热更新生效完整时序：**

```
JS HotUpdateService.downloadAndInstall(manifest)
  ├── ZIP → unzip → SHA256(package) + SHA256(bundle) + 可选 RSA 签名校验
  ├── 写入热更新目录：Documents/hot-updates/packages/{id}/main.jsbundle
  └── activatePackage → HotUpdateBundleStore.setCurrentBundlePath(热更路径)
        └── (immediate 模式) HotUpdateBridge.reloadBundle()
              └── RCTReloadCommandSetBundleURL(热更URL) + RCTTriggerReloadCommandListeners
                    └── 下次 makeRootView 时 ContainerReactNativeDelegate.bundleURL 返回热更路径
```

## 使用 BusinessCardFabricView（新架构原生渲染）

当 JS 层渲染 `BusinessCard` 时：
- **平台 = iOS** 且 **`cardType = 0`** → 渲染 `<BusinessCardFabricView />`（C++ Props 同步绑定，无异步 Bridge 开销）
- **其他情况** → 走 JS 视图实现（保证 Android / 旧卡片 / 未 Codegen 场景可用）

**Props & Events（Codegen 生成）：**

| 属性 | C++ 类型 | ObjC 读取 |
|------|----------|-----------|
| cardData | `std::string` | JSON: {cardId, title, coverUrl...} |
| actions | `std::string` | JSON: [{id, title, actionType}...] |
| cardType | `int` | 渲染样式编号 |
| cornerRadius | `double` | layer.cornerRadius |
| enableShadow | `bool` | layer.shadowOpacity |

| 事件 | 载荷 |
|------|------|
| onCardPress | {cardId} |
| onActionPress | {cardId, actionId, actionType} |
| onExposure | {cardId, timestamp ms} |

## 集成新的业务模块（标准流程）

### Step 1：RN 侧新增 TS Spec
`MyRNModule/specs/NativeFooModule.ts`（TurboModule）/ `NativeFooView.ts`（Fabric）

### Step 2：更新 codegenConfig
`package.json → codegenConfig.ios.modulesProvider / componentProvider` 登记

### Step 3：IOSRNContainer 侧新增 ObjC++ 实现
```objc
// FooTurboModule.h
#import <MyRNAppSpecs/MyRNAppSpecs.h>
@interface FooTurboModule : NSObject <NativeFooModuleSpec>
@end
// FooTurboModule.mm
@implementation FooTurboModule
RCT_EXPORT_MODULE(NativeFooModule)
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<NativeFooModuleSpecJSI>(params);
}
@end
```
Fabric 组件同理：`RCTViewComponentView` + `concreteComponentDescriptorProvider<...>()`

### Step 4：pod install 触发 Codegen
```bash
cd IOSRNContainer
pod install --repo-update
```
生成物：`Pods/Headers/Public/ReactCodegen/MyRNAppSpecs/MyRNAppSpecs.h`

## 运行指南

```bash
# 0. 安装 JS 依赖（首次）
cd ../MyRNModule && npm install

# 1. 安装 CocoaPods 依赖（含 Codegen）
cd IOSRNContainer
pod install --repo-update

# 2. 启动 Metro（另一终端窗口）
cd ../MyRNModule
npx react-native start            # 保持运行

# 3. 编译运行 App
xed -b .                          # 打开 IOSRNContainer.xcworkspace
# Xcode → Cmd+R 运行到 Simulator / Device

# 4. （可选）多开发者配置自定义 Metro IP
# IOSRNContainer/Info.plist 新增 Key: RNMetroServerIP, Value: "192.168.1.100:8081"
```

## 常见问题

| 现象 | 根因 | 处理 |
|------|------|------|
| `command not found: node`（pod install 时） | `/usr/local/bin/node` 未符号化 | `sudo ln -s $(which node) /usr/local/bin/node` |
| BusinessCardFabricView 始终走 JS 兜底 | Codegen 未生成 ComponentDescriptor | `cd IOSRNContainer && pod install` 触发 Codegen |
| `bridgeReady: false` | Bridge 首次加载耗时（~1-3s） | 控制台"重新加载 Bundle"或等待 `RNBridgeManager.preloadIfNeeded` 完成 |
| 热更切换后新页面还是旧内容 | `RCTReloadCommandSetBundleURL` 只对新 Bridge 生效 | 切换后关闭已打开的 RN 页面，重新打开即可 |
| OTA 未更新 | `manifestURL`/`publicKey` 未配置或 SHA256 不匹配 | 检查 `src/config/hotUpdate.ts` + `HotUpdateService.checkForUpdate` 返回值 |

## 关键文件索引

| 职责 | 文件 |
|------|------|
| RN 控制台 5 入口 + 状态面板 | [ViewController.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/IOSRNContainer/ViewController.swift) |
| Factory + RNBridgeManager 双适配 Host | [ReactNativeHost.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/IOSRNContainer/ReactNativeHost.swift) |
| 通用 RN VC（含卡片回调绑定） | [ReactNativeViewController.swift](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/IOSRNContainer/ReactNativeViewController.swift) |
| 业务卡片 TurboModule（含 JSI） | [BusinessCardBridgeTurboModule.mm](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/IOSRNModule/BusinessCardBridgeTurboModule.mm) |
| 业务卡片 Fabric（C++ Props/Events） | [BusinessCardFabricView.mm](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/IOSRNModule/BusinessCardFabricView.mm) |
| CocoaPods 依赖声明 | [Podfile](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/IOSRNContainer/Podfile) |
