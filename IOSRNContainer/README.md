# IOSRNContainer — iOS 原生壳 + React Native 棕地集成

## 项目概述

iOS 原生 App **棕地集成 React Native**（RN 0.76+ New Architecture），展示 **RCTReactNativeFactory 生命周期管理**、**TurboModule + Codegen 双端绑定**、**Fabric Native Component C++ 属性绑定**、**多开发者 Metro IP 协作配置** 的完整实践。RN 源码位于 `../MyRNModule`，通过 CocoaPods 以 Static Framework 方式引入。

## 项目结构

```
IOSRNContainer/
├── IOSRNContainer/
│   ├── AppDelegate.swift                    # App 入口：bootstrap ReactNativeFactory
│   ├── SceneDelegate.swift                  # Scene 生命周期
│   ├── ViewController.swift                 # 原生首页（打开 RN 页面入口）
│   ├── ReactNativeHost.swift                # RN 宿主：单例工厂 + Bundle URL 管理
│   └── ReactNativeViewController.swift      # RN 页面容器 ViewController
├── IOSRNModule/
│   ├── CodegenHeaders/
│   │   └── MyRNAppSpecs.h                  # Codegen 自动生成的 Umbrella Header
│   ├── CounterTurboModule.h                 # TurboModule 头文件（实现 NativeCounterSpec 协议）
│   ├── CounterTurboModule.mm                # TurboModule ObjC++ 实现
│   ├── NativeColoredView.h                  # Fabric Native Component 头文件
│   └── NativeColoredView.mm                 # Fabric Native Component ObjC++ 实现
├── Podfile                                  # CocoaPods：引入 ../MyRNModule + New Architecture 开关
└── Podfile.lock
```

## 架构流程

```
AppDelegate
  └── ReactNativeHost.shared.bootstrap(with: launchOptions)
        ├── ContainerReactNativeDelegate
        │     ├── dependencyProvider = RCTAppDependencyProvider
        │     └── sourceURL → Debug: Metro IP (Info.plist) / RELEASE: main.jsbundle
        └── RCTReactNativeFactory(delegate: delegate)

ViewController (原生首页)
  └── openRNPage() → ReactNativeViewController(moduleName:"MyRNModule", initialProperties:{...})
        └── ReactNativeHost.shared.makeRootView(moduleName:..., properties:...)
              ├── 懒初始化：首次调用时 bootstrap()
              └── rootViewFactory.view(withModuleName:...)
```

---

## 技术要点

### 一、RCTReactNativeFactory 生命周期（ReactNativeHost）

```swift
final class ReactNativeHost {
    static let shared = ReactNativeHost()
    private var reactNativeFactory: RCTReactNativeFactory?

    func bootstrap(with launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard reactNativeFactory == nil else { return }  // 幂等

        let delegate = ContainerReactNativeDelegate()
        delegate.dependencyProvider = RCTAppDependencyProvider()
        reactNativeDelegate = delegate
        reactNativeFactory = RCTReactNativeFactory(delegate: delegate)
    }

    func makeRootView(moduleName: String, initialProperties: [String: Any]?) -> UIView {
        bootstrap()  // 懒初始化
        return reactNativeFactory?.rootViewFactory?.view(
            withModuleName: moduleName,
            initialProperties: initialProperties,
            launchOptions: cachedLaunchOptions
        )
    }
}
```

- **双入口启动**：`AppDelegate.didFinishLaunching` 传入 `launchOptions` + 首次 `makeRootView` 懒初始化
- **幂等保护**：`guard reactNativeFactory == nil` 防止重复创建
- **RCTReactNativeFactory** 是 RN 0.76+ New Architecture 的工厂类，替代旧的 `RCTBridge`

### 二、多开发者 Metro Bundle URL 策略

```swift
final class ContainerReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
    override func bundleURL() -> URL? {
#if DEBUG
        // 从 Info.plist 读取自定义 Metro IP（如 "192.168.1.100:8081"）
        if let customIP = Bundle.main.object(forInfoDictionaryKey: "RNMetroServerIP") as? String,
           !customIP.isEmpty {
            return URL(string: "http://\(customIP)/index.bundle?platform=ios&dev=true&minify=false")
        }
        // 未配置 IP 时自动检测 localhost:8081
        return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
        return Bundle.main.url(forResource: "main", withExtension: "jsbundle")  // Release: 本地打包
#endif
    }
}
```

| 场景 | Bundle 来源 | 说明 |
|------|------------|------|
| Debug + `Info.plist` 配置 `RNMetroServerIP` | `http://{自定义IP}:8081/index.bundle?...` | 团队成员各自配置本机 IP |
| Debug + 未配置 IP | `RCTBundleURLProvider` 自动检测 localhost | 本地开发默认 |
| Release | `main.jsbundle`（App Bundle 内嵌） | 生产发布 |

### 三、CounterTurboModule — Codegen + JSI 绑定

```objc
// 头文件：遵循 Codegen 生成的协议
#import <MyRNAppSpecs/MyRNAppSpecs.h>
@interface CounterTurboModule : NSObject <NativeCounterSpec>
@end

// 实现文件
@implementation CounterTurboModule {
    double _count;
}

RCT_EXPORT_MODULE(NativeCounter)          // 注册模块名与 TS Spec 一致

- (void)getValue:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject {
    resolve(@(_count));
}

- (void)increment:(double)step resolve:...reject:... {
    _count += step;
    resolve(@(_count));
}

- (void)decrement:(double)step resolve:...reject:... {
    _count -= step;
    resolve(@(_count));
}

- (void)reset:(RCTPromiseResolveBlock)resolve reject:... {
    _count = 0;
    resolve(nil);
}

// JSI 绑定：返回 Codegen 生成的 ObjCTurboModule 子类
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
    return std::make_shared<NativeCounterSpecJSI>(params);
}
```

**关键链路：**
```
TS Spec (NativeCounter TurboModule)
  → react-native-codegen
    → MyRNAppSpecs.h (NativeCounterSpec 协议 + NativeCounterSpecJSI C++ 类)
      → CounterTurboModule.mm 实现协议 + 返回 JSI 绑定
        → RCT_EXPORT_MODULE(NativeCounter) 注册
```

- `NativeCounterSpec` 协议由 Codegen 从 TS Spec 自动生成，方法签名与 TS 端类型完全对应
- `getTurboModule:` 是 TurboModule 的核心方法，返回 JSI 对象，JS 层通过 JSI 直接调用，**绕过 Bridge 序列化**
- `RCTPromiseResolveBlock` / `RCTPromiseRejectBlock` 是 JS Promise 对应的 Native 回调

### 四、NativeColoredView — Fabric Native Component

```objc
// 头文件
@interface NativeColoredView : RCTViewComponentView  // Fabric 基类
@end

// 实现文件
@implementation NativeColoredView

// 注册组件的 ComponentDescriptor（Fabric 渲染器需要）
+ (ComponentDescriptorProvider)componentDescriptorProvider {
    return concreteComponentDescriptorProvider<NativeColoredViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        static const auto defaultProps = std::make_shared<const NativeColoredViewProps>();
        _props = defaultProps;  // 设置 C++ 默认 Props
    }
    return self;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
    const auto &newViewProps = *std::static_pointer_cast<const NativeColoredViewProps>(props);
    [super updateProps:props oldProps:oldProps];

    // 从 C++ Props 读取 color 字符串 → UIColor
    if (!newViewProps.color.empty()) {
        self.backgroundColor = [self rgbaFromHexString:
            [NSString stringWithUTF8String:newViewProps.color.c_str()]];
    }

    // 从 C++ Props 读取 cornerRadius
    self.layer.cornerRadius = newViewProps.cornerRadius;
}
```

**Fabric Component 关键要素：**

| 要素 | 代码 | 说明 |
|------|------|------|
| 基类 | `RCTViewComponentView` | Fabric 要求所有 Native View 继承此类 |
| 协议 | `RCTNativeColoredViewViewProtocol` | Codegen 生成，声明 updateProps 等 |
| ComponentDescriptor | `concreteComponentDescriptorProvider<NativeColoredViewComponentDescriptor>()` | 注册到 Fabric 渲染器 |
| Props 读取 | `std::static_pointer_cast<const NativeColoredViewProps>(props)` | 从 C++ 共享指针读取 Codegen 生成的 Props 结构体 |
| HEX 解析 | `rgbaFromHexString:` | 手动实现 `#RRGGBB` / `#AARRGGBB` → `UIColor` |

### 五、Codegen 集成配置

#### Podfile 关键配置

```ruby
# 1. 解析 MyRNModule 的 react_native_pods.rb
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve("react-native/scripts/react_native_pods.rb",
   {paths: [process.argv[1]]},)',
  File.expand_path('../MyRNModule', __dir__)]).strip

# 2. New Architecture 显式开关
ENV['RCT_NEW_ARCH_ENABLED'] = '1'
ENV['USE_FRAMEWORKS'] = 'static'

# 3. 使用 react_native_pods 引入 RN
use_react_native!(
  :path => rn_react_native_path,
  :app_path => rn_app_path      # 指向 MyRNModule，Codegen 从此查找 TS Spec
)

# 4. Post-install: 自动注入 ReactCodegen Header 搜索路径
# 让 IOSRNContainer target 可以 #import <MyRNAppSpecs/MyRNAppSpecs.h>
installer.aggregate_targets.each do |aggregate_target|
  aggregate_target.user_project.targets.each do |target|
    next unless target.name == 'IOSRNContainer'
    target.build_configurations.each do |config|
      paths = config.build_settings['HEADER_SEARCH_PATHS'] || ['$(inherited)']
      codegen_path = '${PODS_ROOT}/Headers/Public/ReactCodegen'
      paths << codegen_path unless paths.include?(codegen_path)
      config.build_settings['HEADER_SEARCH_PATHS'] = paths
    end
  end
end
```

#### Codegen 生成物

```
MyRNModule (TS 源码)
  └── src/native/specs/
        ├── NativeCounter.ts          → Codegen → MyRNAppSpecs.h (NativeCounterSpec + NativeCounterSpecJSI)
        └── NativeColoredView.ts       → Codegen → ComponentDescriptors.h + Props.h + RCTComponentViewHelpers.h
```

- `MyRNAppSpecs.h` 是 Codegen 自动生成的 **Umbrella Header**（`ios/CodegenHeaders/` 目录下的只读文件）
- 包含 `NativeCounterSpec` 协议（声明方法签名）和 `NativeCounterSpecJSI` C++ 类（JSI 绑定定义）
- 包含 `#error This file must be compiled as Obj-C++` 编译期检查，确保 .mm 扩展名

### 六、运行方式

```bash
cd IOSRNContainer
pod install
open IOSRNContainer.xcworkspace

# 多开发者场景：在 Info.plist 中配置 RNMetroServerIP
# <key>RNMetroServerIP</key>
# <string>192.168.1.100:8081</string>

# 启动 Metro（在 MyRNModule 目录）
cd ../MyRNModule
npx react-native start
```

## 与 MyRNModule 的对端关系

| IOSRNContainer (Native) | MyRNModule (RN) |
|------------------------|-----------------|
| `ReactNativeHost.bootstrap()` → `RCTReactNativeFactory` | RN 0.76+ New Architecture bridge startup |
| `CounterTurboModule.mm` → `NativeCounterSpec` 协议 | `src/native/specs/NativeCounter.ts` TS Spec |
| `NativeColoredView.mm` → Fabric Component | `src/native/specs/NativeColoredView.ts` TS Spec |
| `ContainerReactNativeDelegate.bundleURL()` → Metro IP | Metro Bundler (8081) |
| `makeRootView(moduleName:"MyRNModule")` | `index.js` → `AppRegistry.registerComponent('MyRNModule')` |

## 技术标签

`iOS` `React Native` `New Architecture` `TurboModule` `Fabric` `JSI` `Codegen` `CocoaPods` `RCTReactNativeFactory` `RCTViewComponentView` `ComponentDescriptor` `ObjC++` `棕地集成` `Brownfield`
