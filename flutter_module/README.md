# Flutter 混合工程网络层架构 Demo

## 项目概述

一套用于 **Flutter Add-to-App 混合工程** 的生产级模块，核心展示 **Dio 拦截器链网络层架构**、**多环境/多域配置**、**双向混合路由** 及 **PlatformView 动态控制**。所有网络请求通过自定义 `MockAdapter` 模拟，无需真实后端即可完整演示 Token 刷新、缓存、重试、超时等场景。

## 项目结构

```
flutter_module/
├── lib/
│   ├── main.dart              # App 入口，路由中心 + Channel 注册
│   ├── main_test.dart         # Test 环境入口
│   ├── main_preprod.dart      # Preprod 环境入口
│   ├── main_prod.dart         # Prod 环境入口
│   ├── env/
│   │   └── app_env.dart       # 多环境（Flavor）配置
│   ├── network/
│   │   ├── network_client.dart     # 网络请求门面（NetworkClient 单例）
│   │   ├── dio_factory.dart        # Dio 实例工厂（主 Dio / 刷新 Dio）
│   │   ├── domain.dart             # 多域枚举（ApiDomain）
│   │   ├── auth/
│   │   │   ├── token_store.dart    # Token 存储抽象 + InMemoryTokenStore
│   │   │   └── token_refresher.dart # Token 续期器（SingleFlight 防并发）
│   │   ├── interceptors/
│   │   │   ├── unwrap_interceptor.dart    # 响应解包 + 业务异常转换
│   │   │   ├── auth_interceptor.dart      # Bearer Token 注入 + 401 自动刷新
│   │   │   ├── retry_interceptor.dart     # 幂等重试 + 指数退避
│   │   │   ├── cache_interceptor.dart     # GET 请求 TTL 内存缓存
│   │   │   └── logging_interceptor.dart   # requestId 注入 + UA/Sign 头 + 日志
│   │   ├── mock/
│   │   │   └── mock_adapter.dart     # 自定义 HttpClientAdapter（Mock 服务器）
│   │   └── model/
│   │       ├── api_response.dart     # 通用响应体 {code, message, data}
│   │       └── app_exception.dart    # Sealed 异常层级体系
│   ├── ui/
│   │   └── loading/
│   │       ├── loading_controller.dart  # 引用计数式 Loading 控制
│   │       └── loading_overlay.dart     # 全局 Loading 遮罩
│   └── pages/
│       └── dio_demo_page.dart       # 网络层功能演示页
└── pubspec.yaml
```

---

## 技术要点

### 一、多环境（Flavor）架构

```dart
// 编译时常量注入
const raw = String.fromEnvironment('FLAVOR', defaultValue: 'test');

// 运行时覆盖（用于快速切换）
AppEnv.overrideFlavor = AppFlavor.test;

// 环境感知配置
AppEnv.current.baseUrls   // 不同环境不同域名
AppEnv.current.channel    // 渠道标识
AppEnv.current.signature  // 签名密钥
```

| 入口文件 | 环境 | Base URL |
|----------|------|----------|
| `main_test.dart` | test | `https://test-api-*.mock` |
| `main_preprod.dart` | preprod/staging | `https://preprod-api-*.mock` |
| `main_prod.dart` | prod | `https://api-*.mock` |

### 二、Dio 拦截器链架构

拦截器按插入顺序执行，经过精心编排以处理完整的请求生命周期：

```
请求流 →
  LoggingInterceptor     → 注入 requestId/UA/Sign/Env 头，支持单请求超时覆盖
  CacheInterceptor       → GET 命中则直接 resolve，跳过后续拦截器和网络
  _BaseUrlInterceptor    → 根据 ApiDomain 枚举切换 baseUrl
  AuthInterceptor        → 注入 Authorization: Bearer {token}
  ── 网络层/MockAdapter ──
响应流 ←
  UnwrapInterceptor      → 解包 {code, message, data}，code≠0 时抛 BizAppException
  AuthInterceptor(401)   → 触发 TokenRefresher，成功后重放原请求
  RetryInterceptor       → 超时/5xx 指数退避重试
  CacheInterceptor       → 缓存 GET 响应，下次命中直接返回
  LoggingInterceptor     → 打印响应日志
```

#### 各拦截器职责

| 拦截器 | 职责 | 关键实现 |
|--------|------|----------|
| `UnwrapInterceptor` | 统一解包 `{code, message, data}` 协议 | `code == 0` 时 `response.data = api.data`；非 0 时抛出 `BizAppException` |
| `AuthInterceptor` | Token 注入 + 401 自动续期 | `__authRetried` 标记防死循环；刷新成功后带新 Token 重放原请求 |
| `RetryInterceptor` | 幂等/可重试请求的错误重试 | 指数退避 `baseDelay * 2^retryCount`（300ms→600ms→1.2s→max 2s）；仅 GET/HEAD/PUT/DELETE 自动重试，POST 需显式 `retryable: true` |
| `CacheInterceptor` | GET 请求 TTL 内存缓存 | `InMemoryCacheStore` 基于 Map + 惰性过期；`forceRefresh` 可跳过缓存；`cacheKey` 支持自定义键 |
| `_BaseUrlInterceptor` | 多域路由 | 从 `options.extra['domain']` 读取 `ApiDomain` 枚举，动态替换 `options.baseUrl` |
| `LoggingInterceptor` | 请求追踪 + 日志 | 生成全局唯一 `requestId`；注入 `ua/appVersion/env/channel/signature` 头；支持 `timeoutMs` 单请求覆盖；按级别打印 `[DIO][REQ/RES/ERR]` 日志 |

### 三、Token 刷新单飞模式（SingleFlight）

```dart
final class TokenRefresher {
  Future<String>? _refreshing;  // 缓存进行中的刷新

  Future<String> refresh() {
    if (_refreshing != null) return _refreshing!;  // 已在刷新，复用
    // ... 执行刷新逻辑
    _refreshing = null;  // 完成后清空
  }
}
```

- 多个并发 401 只会触发一次 Token 刷新请求
- 使用独立 `refreshDio`（仅含 baseUrl + 日志拦截器，无 Auth 拦截器），避免循环依赖
- 刷新失败时自动清空 Token 存储，抛出 `UnauthorizedAppException`

### 四、异常体系（Sealed Class）

```dart
sealed class AppException implements Exception {
  // 所有异常携带可观测性字段
  final String? requestId;
  final String? baseUrl;
  final int retryCount;
  final bool cacheHit;
}

NetworkAppException    // 网络异常
TimeoutAppException    // 超时
UnauthorizedAppException // 未授权
ServerAppException     // 5xx
BizAppException        // 业务错误（带 code）
UnknownAppException    // 未知异常
```

- `AppException.fromDioException()` 自动将 `DioException` 转为类型化异常
- 每个异常携带 `requestId/baseUrl/retryCount/cacheHit`，便于链路追踪

### 五、NetworkClient 门面

```dart
final res = await NetworkClient.instance.get('/success');
// res.data → 业务数据（已解包）
// res.meta → NetworkMeta(requestId, baseUrl, cacheHit, retryCount, domain)
```

| 特性 | 说明 |
|------|------|
| `autoLoading` | 自动显示/隐藏全局 Loading（通过 `LoadingController` 引用计数管理） |
| `loadingKey` | 多个并发请求共享一个 Loading 状态 |
| `cacheOptions` | 单请求缓存策略（TTL/cacheKey/forceRefresh） |
| `retryOptions` | 单请求重试策略（maxAttempts/baseDelay/maxDelay） |
| `retryable` | POST 等非幂等方法是否可重试 |
| `timeoutMs` | 单请求超时覆盖 |
| `domain` | 指定 `ApiDomain.apiA` 或 `ApiDomain.apiB` |

### 六、Mock 服务器（MockAdapter）

实现 `HttpClientAdapter` 接口，完全接管 Dio 的网络层：

| 路径 | 行为 |
|------|------|
| `/timeout` | 前 2 次抛 `receiveTimeout`，第 3 次成功（验证重试） |
| `/server_error` | 返回 HTTP 500（验证服务端异常处理） |
| `/biz_fail` | 返回 `{code: 1001}`（验证 UnwrapInterceptor 业务异常） |
| `/auth/refresh` | 校验 refreshToken，签发新 Token（验证刷新流程） |
| `/need_auth` | 校验 Bearer Token，expired 时返回 401（验证 Auth 拦截器） |
| `/cached` | 返回 `serverTs`（验证缓存命中） |
| `/domain/info` | 返回当前 baseUrl（验证多域路由） |
| 其他路径 | 返回通用成功响应 |

### 七、Loading 系统

```
LoadingController (引用计数)
  _global: ValueNotifier<int>    → 全局计数，>0 时显示 Loading
  _keyed: Map<String, int>       → 按 key 分组计数

LoadingOverlay (UI)
  ValueListenableBuilder 监听 _global
  → count > 0 时叠加半透明遮罩 + CircularProgressIndicator
  → AbsorbPointer 阻止穿透点击
```

### 八、混合路由 & 多 Channel 通信

与原生壳（iOS `FlutterContainerDemo`）配合时：

```
原生壳 ──pushRoute(params)──→ Flutter Module
Flutter ──routeReady──→ 原生壳（通知渲染完成，触发 Push 动画）
Flutter ──openNative──→ 原生壳（在导航栈中推入原生页面）
Flutter ──closeFlutter(result)──→ 原生壳（pop 并回传结果）
原生壳 ──resetToBootstrap──→ Flutter Module（清理导航栈）
```

| Channel | 通道名 | Codec | 用途 |
|---------|--------|-------|------|
| router | `com.example.hybrid/router` | Standard | 双向路由控制 |
| method | `com.maocf.hybrid/method` | Standard | 请求/响应（getDeviceInfo 等） |
| event | `com.maocf.hybrid/event` | Standard | 流式事件（sensorMock, notificationMock） |
| messageString | `com.maocf.hybrid/message_string` | String | 字符串消息收发 |
| messageStandard | `com.maocf.hybrid/message_standard` | Standard | 结构化消息收发 |
| platformViewControl | `com.maocf.hybrid/platform_view_control` | Standard | PlatformView 动态属性同步 |

### 九、PlatformView 动态控制

```dart
// 创建时传入初始属性
UiKitView(
  viewType: 'com.maocf.hybrid/native_label_view',
  creationParams: { 'text': 'Hello', 'backgroundColor': '#FF6B6B', ... },
  creationParamsCodec: const StandardMessageCodec(),
  onPlatformViewCreated: (viewId) { /* 获取 viewId，开始动态控制 */ },
)

// 运行时通过 MethodChannel 更新原生 View 属性
await platformViewControl.invokeMethod('updateNativeView', {
  'viewId': viewId,
  'text': '新文本',
  'backgroundColor': '#4D96FF',
  ...
});
```

- `creationParams` 负责初始化，`MethodChannel` 负责运行时更新
- 控制面板支持：文本输入、5 色背景选择、4 色文本选择、宽/高/圆角滑块、隐藏开关

### 十、全局错误处理

```dart
FlutterError.onError = (details) {
  FlutterError.presentError(details);
  debugPrint('FlutterError: ${details.exceptionAsString()}');
};

runZonedGuarded(() {
  runApp(const HybridApp());
}, (error, stack) {
  debugPrint('Uncaught zone error: $error');
});
```

---

## 与 FlutterContainerDemo 的关系

本 `flutter_module` 是 `FlutterContainerDemo`（原生 iOS 壳工程）的 Flutter 侧代码。两者的 Channel 名完全一致，可直接对接：

- `FlutterContainerDemo` 中的 `HybridRouter.swift` 对应本模块的 `HybridApp._onMethodCall`
- `FlutterContainerDemo` 中的 `HybridChannelBridge.swift` 对应本模块的 `HybridChannels`
- `routeReady` 协议在两端均实现：Flutter 渲染完成 → 通知原生 → 原生执行 Push 动画

## 运行方式

```bash
cd flutter_module
flutter run
```

- 网络请求均走 MockAdapter，无需真实后端
- 可在 `DioDemoPage` 中点击各按钮观察拦截器链行为
- 打开 Log 开关可在控制台看到完整的 `[DIO][REQ/RES/ERR]` 日志

## 技术标签

`Flutter` `Dio` `拦截器链` `Token 刷新` `SingleFlight` `重试` `缓存` `多环境` `多域` `MockAdapter` `PlatformView` `MethodChannel` `EventChannel` `BasicMessageChannel` `混合路由` `Add-to-App`
