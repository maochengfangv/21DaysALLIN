# FlutterContainerDemo — iOS 原生壳 + Flutter 混合工程

## 项目概述

iOS 原生 App **棕地集成 Flutter**（Add-to-App），展示 Flutter Engine 生命周期管理、**双向路由系统**、**四种 Channel 通信**、**PlatformView 动态控制** 的完整实践。Flutter 源码位于 `../flutter_module`，通过 CocoaPods 引入。

## 项目结构

```
FlutterContainerDemo/
├── FlutterContainerDemo/
│   ├── AppDelegate.swift                    # FlutterEngine 预启动 + 通道挂载
│   ├── SceneDelegate.swift                  # Scene 生命周期 + NavigationController 初始化
│   ├── ViewController.swift                 # 原生首页（6 个 V2 路由演示入口）
│   ├── AppRouter.swift                      # 统一跳转入口 + 异常/登录兜底
│   ├── RouteRegistry.swift                  # 路由元信息注册表 + Deeplink 解析
│   ├── RouteModels.swift                    # 路由模型 / 错误码 / PendingRequestStore
│   ├── ContainerDispatcher.swift            # Native/Flutter 分发 + V2 通道桥
│   ├── BackDispatcher.swift                 # 返回事件统一分流
│   ├── RouteLogger.swift                    # 路由埋点与统计快照
│   ├── HybridFlutterViewController.swift    # 自定义 FlutterViewController 子类
│   ├── HybridRouter.swift                   # 通道名契约 + 业务 Channel 桥
│   ├── NativePageViewController.swift       # Flutter→Native 跳转的目标页面
│   └── NativePlatformView.swift             # FlutterPlatformView 原生渲染实现
├── Podfile                                  # CocoaPods：引入 ../flutter_module
└── Podfile.lock
```

## 架构流程

```
AppDelegate / SceneDelegate
  └── FlutterEngineProvider.shared.startIfNeeded()
        ├── engine.run()              // 启动 FlutterEngine
        ├── GeneratedPluginRegistrant // 注册 Flutter Plugins
        ├── NativePlatformViewRegistrar.register()  // 注册 PlatformView
        ├── HybridChannelBridge.shared.attach()          // 注册业务 Channel
        └── FlutterChannelRouterBridge.shared.attach()   // 注册 V2 路由通道

ViewController (原生首页)
  └── AppRouter.shared.open(routeName: "channel_demos", params:...)
        ├── RouteRegistry 校验（注册表 / needLogin / 版本 / Deeplink 白名单）
        ├── PendingRequestStore 暂存 requestId → onResult
        └── ContainerDispatcher.dispatch()
              ├── .native  → 直接 push 原生 VC
              └── .flutter → 创建 HybridFlutterViewController
                             → showRouteV2 下发 routeName
                             → 等 routeReadyV2 后完成 open 回调
```

---

## 技术要点

### 一、FlutterEngine 生命周期管理

```swift
final class FlutterEngineProvider {
    static let shared = FlutterEngineProvider()
    let engine: FlutterEngine
    private var isRunning = false

    private init() {
        engine = FlutterEngine(name: "main_flutter_engine")  // 命名引擎
    }

    func startIfNeeded() {
        guard !isRunning else { return }
        engine.run()                                      // 启动引擎
        GeneratedPluginRegistrant.register(with: engine)  // 注册所有 Plugin
        NativePlatformViewRegistrar.register(with: engine)
        HybridChannelBridge.shared.attach(engine: engine)         // 挂载业务 Channel
        FlutterChannelRouterBridge.shared.attach(engine: engine)  // 挂载 V2 路由通道
        isRunning = true
    }
}
```

- **预启动**：`AppDelegate.didFinishLaunching` 和 `SceneDelegate.willConnectTo` 均调用 `startIfNeeded()`，缩短首帧等待时间
- **单例 + 幂等**：`isRunning` 标记防止重复初始化
- **命名引擎**：`FlutterEngine(name:)` 支持同一进程内多引擎场景

### 二、V2 路由体系

分层：**入口层动态，能力层静态**。宿主统一入口 `AppRouter` 只负责校验与编排，
真正的容器分发交给 `ContainerDispatcher`，返回事件交给 `BackDispatcher`。

```
ViewController / Deeplink / Flutter 回跳
        │
        ▼
   AppRouter.open(routeName:params:source:onResult:)
        │  ① PendingRequestStore.isDuplicateOpen  ← 0.5s 去重窗口
        │  ② RouteRegistry.resolveMeta            ← 注册表 / path→routeName
        │  ③ RouteRegistry.validate               ← 必填参数 / needLogin / 版本 / Deeplink 安全
        │  ④ FlutterEngineProvider.startIfNeeded  ← Flutter 路由预热
        │  ⑤ PendingRequestStore.store            ← requestId → onResult
        ▼
   ContainerDispatcher.dispatch
        ├── .native  → UINavigationController push/present/replace
        └── .flutter → HybridFlutterViewController
                        └── FlutterChannelRouterBridge.showRouteV2
                                   │
                                   ▼
                        flutter_module  HybridGateway._applyRoute
                                   │  路由表命中 → 渲染
                                   ▼
                        routeReadyV2 { requestId, routeName, canPop }
                                   │
                                   ▼
                ContainerDispatcher.handleFlutterRouteReady → 结束 open 回调
```

失败治理：`routeNotFound / invalidParams / engineNotReady` → `route_error` 兜底页；
`notLogin` → 先跳 `login`，登录成功后用 `loginResumeRequest` 恢复原始路由。

#### 路由 Channel 命令（`com.maocf.hybrid/router_v2`）

| 方向 | 方法 | 参数 | 用途 |
|------|------|------|------|
| Native→Flutter | `showRouteV2` | `routeName / path / params / navStyle / requestId / pageId / animation / presentMode / isFirstEnter` | 下发路由，Flutter 侧渲染目标页面 |
| Native→Flutter | `systemBackV2` | `source / timestamp` | 宿主把返回事件交给 Flutter 内部消费 |
| Native→Flutter | `resetToBootstrapV2` | — | 容器已弹出，要求 Flutter 栈复位 |
| Flutter→Native | `flutterReadyV2` | `version` | Flutter 通道就绪（配合 VC `viewDidAppear` 冲刷 pendingPush） |
| Flutter→Native | `routeReadyV2` | `requestId / routeName / path / canPop` | 页面渲染完成，宿主结束 loading / 完成 open 回调 |
| Flutter→Native | `routeNotFoundV2` | `requestId / routeName / path` | routeName 未注册，宿主走 `route_error` 兜底 |
| Flutter→Native | `canPopV2` | `canPop / routeName / requestId` | 栈深度变化上报，驱动 BackDispatcher 分流 |
| Flutter→Native | `openNativeV2` | `routeName / params` | Flutter → Native 跳转 |
| Flutter→Native | `closeFlutterV2` | `requestId / routeName / result / cancelled` | Flutter 主动关闭容器并回传结果 |

> 通道名为**编译期契约**：iOS 侧 `HybridChannelNames`（HybridRouter.swift）
> 与 Flutter 侧 `HybridChannelNames`（lib/hybrid/hybrid_channels.dart）必须同步修改。

#### Route Ready 协议

```
1. AppRouter 完成校验，ContainerDispatcher 创建 HybridFlutterViewController
2. 若 Flutter 容器已在栈顶 → 直接 showRouteV2；否则先入 pendingPush，等 VC viewDidAppear 冲刷
3. Flutter HybridGateway 命中路由表 → pushNamedAndRemoveUntil(routeName, removeUntil: false)
4. Flutter 在 addPostFrameCallback 中回 routeReadyV2（含 canPop）
5. 宿主 ContainerDispatcher.handleFlutterRouteReady 结束 open 回调
```

**这彻底解决了 Flutter 混合导航白屏问题**：宿主在 Flutter 页面渲染完成后才结束路由回调，
用户看不到空白帧。

#### 返回事件分流（BackDispatcher）

宿主返回（原生导航栏按钮 / 侧滑）统一进入 `BackDispatcher.handleBackPress`，
依据 Flutter 上报的 `flutterCanPop` 做四类分流：

| 条件 | 动作 |
|------|------|
| 栈顶是 Flutter 容器 且 `flutterCanPop == true` | 下发 `systemBackV2`，Flutter 内部出栈 |
| 栈顶是 Flutter 容器 且 `flutterCanPop == false` | 宿主 pop 掉整个 Flutter 容器，并 resolve 结果为 cancelled |
| 栈顶非 Flutter 容器 | `fallthroughToNativePop`，走原生 pop/dismiss |
| Flutter 主动 `closeFlutterV2` | `handleFlutterInitiatedClose`，宿主 pop 容器并回传 payload |

`popInFlight` + `pendingPopToken` 保证快速连点返回时的幂等性。

#### 导航栏三种风格（NavStyle）

| 风格 | 行为 |
|------|------|
| `native` | Flutter 页面由原生 NavigationBar 控制标题和返回，控制器内 `setNavigationBarHidden(false)` |
| `flutter` | Flutter 页面自带 AppBar，原生 NavigationBar 隐藏 |
| `none` | 无导航栏，Flutter 页面内容从 SafeArea 开始 |

#### 结果回传

```swift
// Native 侧监听
let reqId = AppRouter.shared.pushForResult(
    routeName: "counter_demo",
    params: ["initialCount": 10],
    from: self
) { result in
    self.resultLabel.text = "payload: \(String(describing: result.payload))"
}
```

```dart
// Flutter 侧关闭时携带结果
HybridGateway.instance.closeFlutter(
  result: {'counter': 42, 'from': 'ios_pushForResult'},
);
```

### 三、HybridFlutterViewController

```swift
final class HybridFlutterViewController: FlutterViewController {
    let navStyle: HybridNavStyle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 冲刷容器创建前暂存的路由指令，保证首帧即命中目标页面
        if let reqId = currentRequestId {
            FlutterChannelRouterBridge.shared.flushPendingPush(for: reqId)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            ContainerDispatcher.shared.handleFlutterContainerDismissed(requestId: currentRequestId)
            FlutterChannelRouterBridge.shared.notifyFlutterResetToBootstrap()
            // resolve 结果（cancelled）
        }
    }
}
```

- `viewDidAppear` 冲刷 pendingPush，解决「容器先创建、路由后到达」的时序问题
- `isMovingFromParent` 精准判断是 pop 还是 push 其他页面覆盖
- 容器离场时通知 Flutter 栈复位，并 resolve 未完成的 requestId

### 四、四种 Channel 通信（HybridChannelBridge）

| Channel | 通道名 | Codec | 用途 |
|---------|--------|-------|------|
| MethodChannel | `com.maocf.hybrid/method` | Standard | 请求/响应（getDeviceInfo 等） |
| EventChannel | `com.maocf.hybrid/event` | Standard | 双向事件流（sensorMock, notificationMock） |
| BasicMessageChannel | `com.maocf.hybrid/message_string` | String | 字符串消息收发 |
| BasicMessageChannel | `com.maocf.hybrid/message_standard` | Standard | 结构化消息收发 |

#### MethodChannel 方法

| 方法 | 描述 |
|------|------|
| `getDeviceInfo` | 返回设备名称、系统版本、App 版本号 |
| `getScreenMetrics` | 返回屏幕尺寸、StatusBar/NavigationBar/TabBar/SafeArea 高度、屏幕方向 |
| `pickPhotoMock` | 模拟相册选图（延迟 350ms） |
| `getLocationMock` | 模拟定位（返回上海坐标） |

#### EventChannel 事件流

```swift
// 两种事件源
sensorMock:        Timer.scheduledTimer(1.0s) → {x, y, z} 模拟传感器数据
notificationMock:  Timer.scheduledTimer(2.0s) → {id, title, body, badge} 模拟推送通知

// 注册方式
let eventChannel = FlutterEventChannel(name: channelName, binaryMessenger: messenger)
eventChannel.setStreamHandler(eventStreamHandler)
```

- `FlutterStreamHandler.onListen`：启动定时器，初始化 `eventSink`
- `FlutterStreamHandler.onCancel`：停止定时器，释放 `eventSink`
- Timer 加入 `RunLoop.main` 的 `.common` Mode，保证滚动时不暂停

#### BasicMessageChannel

```swift
// StringCodec — 纯字符串
let stringChannel = FlutterBasicMessageChannel(name:..., codec: FlutterStringCodec.sharedInstance())
stringChannel.setMessageHandler { message, reply in
    reply("iOS string echo: \(message ?? "")")
}

// StandardCodec — Map/Dict 等结构化数据
let standardChannel = FlutterBasicMessageChannel(name:..., codec: FlutterStandardMessageCodec.sharedInstance())
standardChannel.setMessageHandler { message, reply in
    reply(["code": 0, "data": [...], "receivedAt": ISO8601DateFormatter()...])
}
```

### 五、PlatformView 系统

```
Flutter Widget 树
  └── UiKitView(viewType: "com.maocf.hybrid/native_label_view")
        └── FlutterPlatformViewFactory.create()
              └── NativePlatformDemoView (原生 UIView)
                    ├── rootView (带圆角 + 半透明背景)
                    ├── boxView (可动态控制尺寸/背景色/圆角/显隐)
                    └── textLabel (文本 + 文字颜色)
```

#### 注册流程

```swift
NativePlatformViewRegistrar.register(with: engine)
  ├── factory = NativePlatformDemoViewFactory(registry: registry)
  ├── registrar.register(factory, withId: viewType)  // 注册工厂
  └── 创建 MethodChannel("com.maocf.hybrid/platform_view_control")
       └── setMethodCallHandler: registry.handle(call:result:)
```

#### 外观注册与查找（WeakBox 模式）

```swift
private final class NativePlatformViewRegistry {
    private final class WeakBox {
        weak var value: NativePlatformDemoView?
    }
    private var views: [Int64: WeakBox] = [:]

    func register(_ view: NativePlatformDemoView, for viewId: Int64) {
        cleanupReleasedViews()          // 先清理已释放的
        views[viewId] = WeakBox(value: view)
    }

    func handle(call: FlutterMethodCall, result: FlutterResult) {
        // 通过 viewId 查找对应 Native View 并调用 update()
    }
}
```

- **weak 引用**：避免 Native View 释放后仍持有引用
- **cleanupReleasedViews**：懒清理策略，在注册新 View 时顺便清理 nil 条目
- **deinit 自动注销**：Native View dealloc 时调用 `registry.unregister(viewId:)`

#### 动态属性控制

```swift
// Flutter 侧通过 MethodChannel 发送更新
platformViewControl.invokeMethod('updateNativeView', {
    'viewId': viewId,
    'text': '新文本',
    'width': 260, 'height': 160,
    'cornerRadius': 24,
    'backgroundColor': '#FF4D96FF',
    'textColor': '#FFFFFFFF',
    'hidden': false,
})

// Native 侧接收并应用
style.update(with: args)  // 安全解析各字段类型
render()                   // 更新约束和颜色
return style.snapshot()    // 返回当前状态供 Flutter 侧确认
```

#### HEX 颜色双向转换

```swift
// #RRGGBB → UIColor (6位) or #AARRGGBB → UIColor (8位)
UIColor(hexString: "#FF4D96FF")

// UIColor → #AARRGGBB
color.hexString()  // "#FF4D96FF"
```

### 六、CocoaPods 集成

```ruby
# Podfile
flutter_application_path = '../flutter_module'
load File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')

target 'FlutterContainerDemo' do
  use_frameworks!
  install_all_flutter_pods(flutter_application_path)  # 自动引入 Flutter 和所有 Plugin
end

post_install do |installer|
  flutter_post_install(installer)
end
```

- `flutter_module` 的 `.ios/Flutter/podhelper.rb` 自动管理 Flutter SDK 和 Plugin 的 Pod 依赖
- `install_all_flutter_pods` 无需手动声明每个 Flutter Plugin

---

## 与 flutter_module 的对端关系

| FlutterContainerDemo (Native) | flutter_module (Flutter) |
|------------------------------|--------------------------|
| `FlutterChannelRouterBridge.attach(engine:)` → 注册 `com.maocf.hybrid/router_v2` | `HybridGateway.bootstrap(resolver:)` 安装 `routerV2` 方法处理器 |
| `showRouteV2/systemBackV2/resetToBootstrapV2` 下发导航指令 | `HybridGateway._handleNativeCall` 分发 → `HybridRouteTable` 解析页面 |
| 等待 `routeReadyV2`（含 canPop）结束 loading / 完成 open 回调 | `addPostFrameCallback(() => _notifyRouteReady(args))` |
| `BackDispatcher` 依据 `canPopV2` 决定返回事件分流 | `HybridNavigatorObserver` 在栈变化后 `reportCanPop()` |
| `HybridChannelBridge.attach(engine:)` → 注册 method/event/message Channel | `HybridChannels` + `MethodChannelDemoPage` 等页面 |
| `NativePlatformViewRegistrar.register()` → `com.maocf.hybrid/native_label_view` | `HybridChannelNames.nativeViewType` + `PlatformViewDemoPage` 中的 `UiKitView` |
| 通道名契约 `HybridChannelNames`（HybridRouter.swift） | 通道名契约 `HybridChannelNames`（hybrid/hybrid_channels.dart） |

---

## 运行方式

```bash
cd FlutterContainerDemo
pod install
open FlutterContainerDemo.xcworkspace
# Xcode 中选择模拟器 → Run
```

## 技术标签

`iOS` `Flutter Add-to-App` `棕地集成` `FlutterEngine` `V2 路由协议` `AppRouter` `RouteRegistry` `BackDispatcher` `Route Ready` `canPop 同步` `MethodChannel` `EventChannel` `BasicMessageChannel` `PlatformView` `UiKitView` `WeakBox` `CocoaPods`
