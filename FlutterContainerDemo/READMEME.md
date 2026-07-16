# FlutterContainerDemo — iOS 原生壳 + Flutter 混合工程

## 项目概述

iOS 原生 App **棕地集成 Flutter**（Add-to-App），展示 Flutter Engine 生命周期管理、**双向路由系统**、**四种 Channel 通信**、**PlatformView 动态控制** 的完整实践。Flutter 源码位于 `../flutter_module`，通过 CocoaPods 引入。

## 项目结构

```
FlutterContainerDemo/
├── FlutterContainerDemo/
│   ├── AppDelegate.swift                    # FlutterEngine 预启动
│   ├── SceneDelegate.swift                  # Scene 生命周期 + NavigationController 初始化
│   ├── ViewController.swift                 # 原生首页（触发 Flutter 路由入口）
│   ├── HybridFlutterViewController.swift    # 自定义 FlutterViewController 子类
│   ├── HybridRouter.swift                   # 双向路由系统（核心）
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
        ├── HybridRouter.shared.attach()    // 注册路由 Channel
        └── HybridChannelBridge.shared.attach()  // 注册业务 Channel

ViewController (原生首页)
  └── HybridRouter.showFlutter(route: "/channel_demos", params:..., onResult:...)
        └── 创建 HybridFlutterViewController → 通过 MethodChannel 通知 Flutter 渲染
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
        HybridRouter.shared.attach(engine: engine)        // 挂载路由系统
        HybridChannelBridge.shared.attach(engine: engine) // 挂载业务 Channel
        isRunning = true
    }
}
```

- **预启动**：`AppDelegate.didFinishLaunching` 和 `SceneDelegate.willConnectTo` 均调用 `startIfNeeded()`，缩短首帧等待时间
- **单例 + 幂等**：`isRunning` 标记防止重复初始化
- **命名引擎**：`FlutterEngine(name:)` 支持同一进程内多引擎场景

### 二、双向路由系统（HybridRouter）

```
┌─────────────┐  showFlutter() + params    ┌──────────────────┐
│  原生 Navigation │ ──────────────────────────▶ │  Flutter Module   │
│  Controller      │ ◀────────────────────────── │  (flutter_module)  │
└─────────────┘  onResult() payload          └──────────────────┘
       ▲                                              │
       │          openNative(route, params)            │
       └──────────────────────────────────────────────┘
```

#### 路由 Channel 命令

| 方向 | MethodChannel 方法 | 用途 |
|------|-------------------|------|
| Native→Flutter | `showRoute(route, params, requestId, navStyle)` | 通知 Flutter 渲染指定页面 |
| Flutter→Native | `routeReady(route, requestId)` | Flutter 页面渲染完成，Native 可以 Push |
| Flutter→Native | `openNative(route, params)` | Flutter 内部触发打开原生页面 |
| Flutter→Native | `closeFlutter(result)` | Flutter 页面关闭，携带返回值 |
| Native→Flutter | `resetToBootstrap` | 清除 Flutter 导航栈 |
| Native→Flutter | `flutterReady` | Flutter Engine 初始化完成信号 |

#### Route Ready 协议（核心创新）

```
1. Native 调用 showFlutter(from:route:params:navStyle:onResult:)
2. Native 创建 HybridFlutterViewController，暂不 Push
3. Native 通过 MethodChannel 向 Flutter 发送 showRoute
4. Flutter 收到后渲染目标页面
5. Flutter 在 addPostFrameCallback 中回复 routeReady
6. Native 收到 routeReady，执行 navigationController.push()
```

**这彻底解决了 Flutter 混合导航白屏问题**：确保 Flutter 页面渲染完成后 Native 才执行 Push 动画，用户看不到空白帧。

#### 导航栏三种风格（NavStyle）

| 风格 | 行为 |
|------|------|
| `native` | Flutter 页面由原生 NavigationBar 控制标题和返回，控制器内 `setNavigationBarHidden(false)` |
| `flutter` | Flutter 页面自带 AppBar，原生 NavigationBar 隐藏 |
| `none` | 无导航栏，Flutter 页面内容从 SafeArea 开始 |

#### 结果回传

```swift
// Native 侧监听
HybridRouter.shared.showFlutter(from: self, route: "/counter", params: [...]) { result in
    self.resultLabel.text = "Result: \(String(describing: result))"
}

// Flutter 侧关闭时携带结果
closeFlutterWithResult({'counter': 42, 'from': 'flutter'})
```

### 三、HybridFlutterViewController

```swift
final class HybridFlutterViewController: FlutterViewController {
    let navStyle: HybridNavStyle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(navStyle != .native, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            HybridRouter.shared.handleFlutterViewControllerDismissed()
        }
    }
}
```

- `isMovingFromParent` 精准判断是 pop 还是 push 其他页面覆盖
- 离开时恢复原生导航栏状态
- 通知 `HybridRouter` 清理暂存的路由请求和回调

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
| `HybridRouter.attach(engine:)` → 注册 `com.example.hybrid/router` | `HybridApp._onMethodCall` 处理 `pushRoute/showRoute/resetToBootstrap` |
| `HybridChannelBridge.attach(engine:)` → 注册 method/event/message Channel | `HybridChannels` + `MethodChannelDemoPage` 等页面 |
| `NativePlatformViewRegistrar.register()` → `com.maocf.hybrid/native_label_view` | `PlatformViewDemoPage` 中的 `UiKitView` |
| `showRoute("routeReady")` 等待 Flutter 信号 | `addPostFrameCallback(() => invokeMethod('routeReady'))` |

---

## 运行方式

```bash
cd FlutterContainerDemo
pod install
open FlutterContainerDemo.xcworkspace
# Xcode 中选择模拟器 → Run
```

## 技术标签

`iOS` `Flutter Add-to-App` `棕地集成` `FlutterEngine` `双向路由` `Route Ready` `MethodChannel` `EventChannel` `BasicMessageChannel` `PlatformView` `UiKitView` `WeakBox` `CocoaPods`
