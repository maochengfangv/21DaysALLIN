# RN 新架构 Bridgeless 模式下原生向 RN 发事件：一次踩坑与复盘

> 从“灰色按钮半点反应没有”到“一秒定位根因”——复盘 React Native 0.86 Bridgeless 模式下 `RCTEventEmitter` 失效的全过程。


## 背景

最近在 React Native 0.86 新架构下开发一个原生容器 `IOSRNContainer` 嵌 RN 模块 `MyRNModule` 的项目。业务需求很简单：**原生 UI 层（Swift）向 RN（TypeScript）推送多场景业务数据**。

架构设计也很常规：

```
Swift (ReactNativeViewController)
  → bridge.module(forName:) 拿到 RCTEventEmitter 实例
  → sendBusinessData:payload:
  → NativeEventEmitter (TS 侧监听)
```

一切看起来和旧架构没什么区别。直到我跑起来点了右上角的场景按钮——

**RN 侧数据纹丝不动。**


## 现象

`ReactNativeViewController` 右上角有三个按钮（场景A / 场景B / 场景C），点击后调用 `sendBusinessData`：

```swift
private func sendBusinessData(callbackId: String, payload: [String: Any]) {
  guard let bridge = ReactNativeHost.shared.bridge else {
    return  // ← 永远走到这里
  }
  // ... 下面那一大堆 module(forName:), perform selector 全都没执行
}
```

而 `ReactNativeHost.bridge` 的实现是：

```swift
var bridge: RCTBridge? {
  if let bridge = reactNativeFactory?.bridge {
    return bridge
  }
  return reactNativeFactory?.rootViewFactory.bridge
}
```

直觉告诉我：**bridge 是 nil**。加了断点，果然。

RN 页面正常渲染、JS 代码正常执行、TurboModule 正常通信，唯独 bridge 不存在。这就很割裂了——bridge 不存在，那所有依赖 `RCTBridgeModule` 的老模块（包括 `RCTEventEmitter`）是怎么活下来的？


## 根因分析

翻开源码 [RCTReactNativeFactory.h](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNModule/node_modules/react-native/Libraries/AppDelegate/RCTReactNativeFactory.h)：

```objc
@property (nonatomic, nullable) RCTBridge *bridge
    __attribute__((deprecated(
      "The bridge is deprecated and will be removed when "
      "removing the legacy architecture."
    )));
```

关键信息：
1. **RN 0.76+ 默认 New Architecture + Bridgeless**
2. `RCTBridge` 已是 `deprecated`，`reactNativeFactory.bridge` 返回 nil
3. `rootViewFactory.bridge` 在 bridgeless 下同样不被赋值

但这不意味着 `RCTBridgeModule` 死了。React Native 内部 **仍然会初始化 `RCTBridgeModule` 实例并发送 `setBridge:` 消息**——这是向后兼容的桥接层干的活。换句话说：

- JS 侧 `NativeModules.RNBusinessEventEmitter` 能拿到模块 → 证明模块被初始化了
- ObjC 侧 `self.bridge` 在 `sendBusinessData:payload:` 里是非 nil → 证明 bridge 确实通过兼容层注入了
- 但 Swift 侧 `ReactNativeHost.shared.bridge` 是 nil → 因为 `RCTReactNativeFactory` 不再暴露它

**结论：bridge 还活着，只是你不应该再从 `RCTReactNativeFactory` 获取它了。** 问题出在“如何拿到 emitter 实例”这一环。


## 修复方案：单例桥接

核心思路：既然 `RNBusinessEventEmitter.init` 一定会被 RN 调用一次，那就在 `init` 里把自己存起来，Swift 侧绕过 bridge 直接拿。

### Step 1：Emitter 加单例

```objc
// RNBusinessEventEmitter.h
@interface RNBusinessEventEmitter : RCTEventEmitter <RCTBridgeModule>

/// 单例：RN 初始化模块时自动赋值
+ (nullable instancetype)sharedInstance;

- (void)sendBusinessData:(NSString *)callbackId
                 payload:(NSDictionary *)payload;
@end
```

```objc
// RNBusinessEventEmitter.m
static RNBusinessEventEmitter *_sharedInstance = nil;

@implementation RNBusinessEventEmitter

RCT_EXPORT_MODULE(RNBusinessEventEmitter)

+ (nullable instancetype)sharedInstance {
  return _sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _sharedInstance = self;  // RN 初始化模块时自动赋值
  }
  return self;
}

// ... supportedEvents, sendBusinessData 不变
@end
```

### Step 2：Swift 优先用单例

```swift
private func sendBusinessData(callbackId: String, payload: [String: Any]) {
  // 优先通过单例获取（bridgeless 兼容）
  if let cls = NSClassFromString("RNBusinessEventEmitter") as? NSObject.Type,
     let emitter = cls.perform(
       NSSelectorFromString("sharedInstance")
     )?.takeUnretainedValue() as? NSObject,
     emitter.responds(to: NSSelectorFromString("sendBusinessData:payload:")) {
    emitter.perform(
      NSSelectorFromString("sendBusinessData:payload:"),
      with: callbackId,
      with: payload as NSDictionary
    )
    return
  }

  // 降级：旧架构下通过 bridge 获取
  guard let bridge = ReactNativeHost.shared.bridge else { return }
  // ...
}
```

不需要 bridging header，不需要改 xcodeproj，纯运行时派发。


## 方案对比

| | bridge.module(forName:) | 单例 |
|---|---|---|
| 旧架构 (Paper) | ✅ | ✅ |
| 新架构 (Bridgeless) | ❌ nil | ✅ |
| 需要 bridging header | Y（或 performSelector） | N |
| 获取失败概率 | 高（bridge 生命周期不确定性） | 低（仅冷启动时模块未初始化） |
| 代码侵入性 | 低 | 低（一个 static 变量） |


## 教训

1. **Bridgeless ≠ 没有 bridge**。`RCTBridge` 仍然存在，只是新架构不再建议你从工厂获取它。RN 内部通过兼容层保证 `RCTBridgeModule` 继续工作。

2. **`RCTEventEmitter` 还能用**。即使 bridgeless，`RCTEventEmitter` 的子类仍然被 RN 初始化并注入 bridge，`sendEventWithName:` 正常工作。

3. **唯一的问题是“获取实例的方式”**。`bridge.module(forClass:)` 在 bridgeless 下失效，因为 `RCTReactNativeFactory.bridge` 返回 nil。解决办法不是抛弃 `RCTEventEmitter`，而是换一种方式拿到实例——单例是最轻量的选择。

4. **如果你还在用旧架构的 `bridge.module(forName:)` 获取模块**，升级到 RN 0.76+ 后大概率会踩同样的坑。建议迁移策略：
   - 优先：单例 / 静态注册
   - 降级：保持 `bridge.module(forName:)` 作为 fallback
   - 长期：关注 RN 官方对 bridgeless 下 `RCTEventEmitter` 的最佳实践更新


## 附：完整事件链路图

```
┌──────────────────────┐     ┌──────────────────────────┐
│ ReactNativeHost      │     │ RNBusinessEventEmitter   │
│ (Swift)              │     │ (ObjC)                   │
│                      │     │                          │
│ bootstrap()          │     │ init() {                 │
│ factory.bridge = nil │     │   _sharedInstance = self │  ← 单例赋值
└──────────────────────┘     └────────┬─────────────────┘
                                      │
┌──────────────────────┐              │
│ ViewController (Swift)│             │
│                      │             │
│ NSClassFromString()  │────────────→│  ← 绕过 bridge
│ sharedInstance()     │             │
│ sendBusinessData()   │             │
└──────────────────────┘     ┌───────┴─────────────────┐
                             │ sendEventWithName:      │
                             │   @"BusinessData"        │
                             └────────┬────────────────┘
                                      │
┌──────────────────────┐              │
│ BusinessDataHandler  │←─────────────┘  ← NativeEventEmitter
│ (TS)                 │
│ switch(callbackId)   │
│  → ScenePayloadMap   │  ← 类型安全分发
└──────────────────────┘
```

---

*完整代码在 [MyRNModule](https://github.com) 和 [IOSRNContainer](https://github.com) 仓库中。如果你也在 Bridgeless 模式下踩过坑，欢迎评论区补充讨论。*
