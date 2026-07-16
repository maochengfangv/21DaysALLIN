# Flutter Plugin 双端原生通信 Demo

## 项目概述

一个用于演示 **Flutter Plugin 开发最佳实践** 的插件包，实现 **MethodChannel / EventChannel / BasicMessageChannel** 四种通信模式的 **双端（iOS Swift / Android Kotlin）** 原生实现。采用统一的请求/响应协议，错误码体系、参数抽取工具在三端完全一致。

## 项目结构

```
flutter_plugin/
├── lib/
│   ├── flutter_plugin.dart                        # 导出文件
│   ├── flutter_plugin_platform_interface.dart      # 平台接口抽象（PlatformInterface token 模式）
│   ├── flutter_plugin_method_channel.dart          # MethodChannel 默认实现
│   └── src/
│       ├── channel_names.dart                     # 三端统一的 Channel 名常量
│       ├── protocol.dart                          # 请求/响应协议、错误码、Result 泛型
│       └── flutter_plugin_api.dart                 # 高层类型化 API（FlutterPluginApi）
├── ios/
│   └── Classes/
│       └── FlutterPlugin.swift                    # iOS Native 实现（4 Channel）
├── android/
│   └── src/main/kotlin/com/example/flutter_plugin/
│       ├── FlutterPlugin.kt                       # Android Native 实现（4 Channel + ActivityAware）
│       ├── FlutterPluginPlugin.kt                 # Plugin 注册入口
│       ├── Args.kt                                # 参数安全提取
│       ├── Protocol.kt                            # 错误码 + 响应构建器
│       ├── ChannelNames.kt                        # Channel 名常量
│       └── Ticker.kt                              # 定时 tick 生成器
├── example/                                       # 完整示例 App（iOS + Android）
│   └── integration_test/
│       └── plugin_integration_test.dart           # 集成测试
├── test/
│   ├── flutter_plugin_test.dart
│   └── flutter_plugin_method_channel_test.dart
└── pubspec.yaml
```

---

## 技术要点

### 一、平台接口抽象（PlatformInterface Token 模式）

遵循 Flutter 官方推荐的 Plugin 架构模式：

```dart
abstract class FlutterPluginPlatform extends PlatformInterface {
  FlutterPluginPlatform() : super(token: _token);
  static final Object _token = Object();

  static FlutterPluginPlatform _instance = MethodChannelFlutterPlugin();
  static FlutterPluginPlatform get instance => _instance;

  static set instance(FlutterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);  // 防止非子类注入
    _instance = instance;
  }
}
```

- `PlatformInterface.verifyToken` 确保只有 `FlutterPluginPlatform` 的子类才能设置实例
- `MethodChannelFlutterPlugin` 为默认实现，可在测试中 Mock 替换

### 二、统一通信协议（三端一致）

#### 请求格式

```dart
PluginRequest(
  version: 1,               // 协议版本，向前兼容
  requestId: 'method-123',  // 唯一请求 ID，链路追踪
  type: 'getDeviceInfo',    // 请求类型
  payload: {'key': 'value'}, // 业务参数
)
```

#### 响应格式

```dart
Result<T>(
  code: PluginErrorCode.ok,  // 错误码（0=成功, 1-5 为各异常类型）
  message: 'ok',
  requestId: 'method-123',
  data: T?,                  // 泛型业务数据
)
```

#### 错误码体系（三端一致）

| 枚举值 | 码值 | Dart | iOS Swift | Android Kotlin |
|--------|------|------|-----------|----------------|
| `ok` | 0 | `PluginErrorCode.ok` | `PluginErrorCodes.ok` → 0 | `PluginErrorCodes.OK` → 0 |
| `badArgs` | 1 | | | |
| `notSupported` | 2 | | | |
| `permissionDenied` | 3 | | | |
| `permissionPermanentlyDenied` | 4 | | | |
| `internalError` | 5 | | | |

- iOS/Android 端均实现 `PluginErrorCodes` 常量对象 + `PluginResponse.ok()`/`PluginResponse.error()` 响应构建器
- 三端 `Args` 工具类：`getString`/`getInt`/`getMap`，缺失或类型错误时统一抛出 `PluginException(badArgs)`

### 三、四种 Channel 通信模式

| Channel | Dart 常量名 | iOS/Android 常量名 | Codec | 方向 |
|---------|------------|-------------------|-------|------|
| MethodChannel | `com.example.flutter_plugin/method` | `METHOD` | Standard | Flutter→Native（请求/响应） |
| EventChannel | `com.example.flutter_plugin/events` | `EVENTS` | Standard | Native→Flutter（事件流） |
| BasicMessageChannel | `com.example.flutter_plugin/message_string` | `MESSAGE_STRING` | String (JSON) | 双向（字符串消息） |
| BasicMessageChannel | `com.example.flutter_plugin/message_standard` | `MESSAGE_STANDARD` | Standard | 双向（结构化消息） |

#### MethodChannel 方法列表

| 方法 | 功能 | 参数 |
|------|------|------|
| `getPlatformVersion` | 获取平台版本 | 无 |
| `getDeviceInfo` | 获取设备信息（platform/model/systemVersion/appVersion等） | 无 |
| `requestCameraPermission` | 请求相机权限 | 无 |
| `startTicking` | 启动定时 tick 事件流 | `payload.intervalMs: int` |
| `stopTicking` | 停止 tick 事件流 | 无 |

#### EventChannel 事件格式

```dart
{
  "eventName": "tick",           // 事件类型
  "timestamp": 1721000000000,    // Unix 毫秒时间戳
  "payload": {
    "count": 42,                 // tick 计数
  }
}
```

- `tick` 事件：由 `startTicking(intervalMs)` 启动，按指定间隔发送
- `permission` 事件：权限请求结果完成后主动推送

#### BasicMessageChannel - StringCodec

```dart
// Dart 侧发送 JSON 字符串
final request = PluginRequest(version: 1, requestId: '...', type: 'echoString', payload: {'text': 'hello'});
await _messageString.send(request.toJsonString());

// iOS 侧：JSONSerialization 解析 → 处理 → encodeJsonString 返回
// Android 侧：JSONObject 解析 → 处理 → JSONObject.toString() 返回
```

#### BasicMessageChannel - StandardCodec

```dart
// Dart 侧发送 Map
final request = PluginRequest(...).toMap();
final raw = await _messageStandard.send(request);

// iOS 侧：返回 Map + FlutterStandardTypedData (bytes)
// Android 侧：返回 Map + byteArray
```

### 四、Dart 侧 API 设计（FlutterPluginApi）

```dart
final api = FlutterPluginApi();

// 类型安全的 Result<T> 返回
final result = await api.getDeviceInfo();
// result.code     → PluginErrorCode
// result.data     → Map<String, Object?> (platform, model, systemVersion...)
// result.requestId → 链路追踪 ID
// result.isOk     → bool

// 统一错误处理在 _invoke<T> 中完成
// PlatformException / 类型转换失败 → Result(internalError)
```

- `_invoke<T>` 为 MethodChannel 调用的通用模板方法
- `RequestId.create(type)` 生成格式为 `{type}-{timestamp}-{counter}-{salt}` 的唯一 ID
- `Result.fromMap<T>` 支持自定义 `dataParser` 进行类型转换

### 五、iOS Native 实现要点

```swift
public class SwiftFlutterPluginPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  // 4 个 Channel 在 register() 中一次性注册
  // MethodChannel → addMethodCallDelegate
  // EventChannel  → setStreamHandler
  // BasicMessageChannel × 2 → setMessageHandler
}
```

| 要点 | 实现 |
|------|------|
| 定时器 | `DispatchSource.makeTimerSource` + `.schedule(deadline:repeating:)` |
| 相机权限 | `AVCaptureDevice.authorizationStatus` / `requestAccess` |
| StringCodec JSON | `JSONSerialization` 解析 → 处理 → `encodeJsonString` (含 NSNull 处理) |
| 权限状态推送 | 权限结果通过 `eventSink` 推送 `permission` 事件 |
| 参数安全提取 | `Args.asMap()/getString()/getInt()/getMap()` 抛出 `PluginException` |

### 六、Android Native 实现要点

```kotlin
open class FlutterPluginImpl :
    FlutterPlugin,
    ActivityAware,                              // Activity 生命周期感知
    MethodCallHandler,                          // MethodChannel 回调
    EventChannel.StreamHandler,                 // EventChannel 生命周期
    PluginRegistry.RequestPermissionsResultListener  // 权限结果回调
```

| 要点 | 实现 |
|------|------|
| 定时器 | `Ticker` 类基于 `Handler(Looper.getMainLooper())` + `postDelayed` |
| 相机权限 | `checkSelfPermission` / `requestPermissions` / `onRequestPermissionsResult` |
| `permanentlyDenied` 判断 | `shouldShowRequestPermissionRationale == false` 且未授权 |
| StringCodec JSON | `JSONObject` 解析 → 处理 → `toString()` |
| Activity 生命周期 | `onAttachedToActivity` / `onDetachedFromActivity` / `onReattachedToActivityForConfigChanges` |
| 资源释放 | `onDetachedFromEngine` 中清空 4 个 Channel handler + 停止 ticker |
| 参数安全提取 | Kotlin `Args` 支持 `Int/Long/Double/toString` 多类型转换 |

### 七、三端协议一致性对照

| 组件 | Dart (`lib/src/`) | iOS (`ios/Classes/`) | Android (`android/.../`) |
|------|-------------------|---------------------|-------------------------|
| Channel 名 | `FlutterPluginChannelNames` | `FlutterPluginChannelNames` (enum) | `FlutterPluginChannelNames` (object) |
| 错误码 | `PluginErrorCode` (enum) | `PluginErrorCodes` (enum) | `PluginErrorCodes` (object) |
| 异常 | `PluginException` (class) | `PluginException` (final class, Error) | `PluginException` (RuntimeException) |
| 响应构建 | `Result<T>` (class) | `PluginResponse.ok/error` (enum) | `PluginResponse.ok/error` (object) |
| 参数提取 | 内置在 `_invoke` | `Args.asMap/getString/getInt/getMap` | `Args.getString/getInt/getMap` |

---

## 使用方式

```dart
import 'package:flutter_plugin/flutter_plugin.dart';

final api = FlutterPluginApi();

// MethodChannel 调用
final deviceInfo = await api.getDeviceInfo();
print(deviceInfo.data); // {platform: ios, model: iPhone, ...}

// 启动 EventChannel 并监听
api.eventStream.listen((event) {
  print('${event['eventName']}: ${event['payload']}');
});
await api.startTicking(intervalMs: 1000);

// BasicMessageChannel - String
final echo = await api.sendStringMessage(text: 'hello');
print(echo.data); // "iOS echo: hello"

// BasicMessageChannel - Standard
final standardEcho = await api.sendStandardMessage(payload: {'text': 'hello', 'number': 42});
print(standardEcho.data); // {platform: ios, receivedPayload: {...}, ...}

await api.stopTicking();
```

## 测试

```bash
# 单元测试
cd flutter_plugin
flutter test

# 集成测试（需要模拟器）
cd flutter_plugin/example
flutter test integration_test/plugin_integration_test.dart
```

## 技术标签

`Flutter Plugin` `MethodChannel` `EventChannel` `BasicMessageChannel` `PlatformInterface` `iOS Swift` `Android Kotlin` `ActivityAware` `权限请求` `DispatchSourceTimer` `三端协议一致`
