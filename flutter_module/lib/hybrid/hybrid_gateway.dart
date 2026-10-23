import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'hybrid_channels.dart';
import 'hybrid_route.dart';

/// 路由注册表契约。
///
/// 网关只依赖契约（依赖反转），具体路由表由壳层注入，
/// 从而避免「网关 ↔ 页面」之间形成编译期循环依赖。
abstract interface class HybridRouteResolver {
  /// routeName 是否已在 Flutter 侧注册。
  bool isRegistered(String routeName);

  /// 构建路由；未注册返回 null。
  Route<void>? buildRoute(RouteSettings settings, HybridRouteArgs args);
}

/// Flutter 侧混合路由网关（单例收口）。
///
/// 职责：
/// - 安装 Native → Flutter 的方法处理器（showRouteV2 / systemBackV2 / resetToBootstrapV2）
/// - 向 Native 上报状态（flutterReadyV2 / routeReadyV2 / routeNotFoundV2 / canPopV2 / closeFlutterV2）
/// - 维护当前路由栈上下文（routeName / requestId / canPop）
final class HybridGateway {
  HybridGateway._();

  static final HybridGateway instance = HybridGateway._();

  /// 全局 Navigator 句柄，`MaterialApp.navigatorKey` 与本网关共享同一实例。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 栈深度监听器，供 `MaterialApp.navigatorObservers` 挂载。
  final NavigatorObserver navigatorObserver = HybridNavigatorObserver();

  HybridRouteResolver? _resolver;
  HybridRouteArgs? _pendingRoute;
  String? _currentRouteName;
  String? _currentRequestId;
  bool? _lastReportedCanPop;
  bool _bootstrapped = false;

  /// 当前路由名（供页面回传结果使用）。
  String? get currentRouteName => _currentRouteName;

  /// 当前路由对应的 Native 请求 ID。
  String? get currentRequestId => _currentRequestId;

  /// 壳层装配：注入路由表并安装 Native → Flutter 方法处理器。
  void bootstrap({required HybridRouteResolver resolver}) {
    _resolver = resolver;
    if (_bootstrapped) return;
    _bootstrapped = true;

    HybridChannels.routerV2.setMethodCallHandler(_handleNativeCall);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_notifyFlutterReady());
      _flushPendingRoute();
    });
  }

  // MARK: - Flutter → Native

  /// Flutter 主动关闭容器并回传结果。
  Future<void> closeFlutter({Object? result, bool cancelled = false}) async {
    await _invoke(HybridOutboundMethods.closeFlutter, <String, Object?>{
      'version': hybridProtocolVersion,
      'requestId': _currentRequestId,
      'routeName': _currentRouteName,
      'result':
          result ?? const <String, Object?>{'message': 'closed from flutter'},
      'cancelled': cancelled,
    });
  }

  /// Flutter → Native 跳转（宿主按 RouteRegistry 校验后分发）。
  Future<void> openNative({
    required String routeName,
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    await _invoke(HybridOutboundMethods.openNative, <String, Object?>{
      'version': hybridProtocolVersion,
      'routeName': routeName,
      'params': params,
    });
  }

  /// 页面内返回：Flutter 栈可退则退，否则关闭整个容器。
  Future<void> popOrClose({Map<String, Object?>? closePayload}) async {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    await closeFlutter(result: closePayload);
  }

  /// 上报 Flutter 栈是否可继续回退。
  ///
  /// 宿主 [BackDispatcher] 依据该状态决定返回事件是「Flutter 内部消费」
  /// 还是「弹出整个 Flutter 容器」，因此必须在每次栈深度变化后同步。
  Future<void> reportCanPop({bool force = false}) async {
    final canPop = navigatorKey.currentState?.canPop() ?? false;
    if (!force && canPop == _lastReportedCanPop) return;
    _lastReportedCanPop = canPop;
    await _invoke(HybridOutboundMethods.canPop, <String, Object?>{
      'version': hybridProtocolVersion,
      'canPop': canPop,
      'routeName': _currentRouteName,
      'requestId': _currentRequestId,
    });
  }

  // MARK: - Native → Flutter

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case HybridInboundMethods.showRoute:
        _handleShowRoute(_asStringMap(call.arguments));
        return null;
      case HybridInboundMethods.systemBack:
        _handleSystemBack();
        return null;
      case HybridInboundMethods.resetToBootstrap:
        _handleResetToBootstrap();
        return null;
      default:
        throw PlatformException(code: 'not_implemented', message: call.method);
    }
  }

  void _handleShowRoute(Map<String, dynamic> raw) {
    final args = HybridRouteArgs.fromNative(raw);
    if (navigatorKey.currentState == null) {
      _pendingRoute = args;
      return;
    }
    _applyRoute(args);
  }

  void _applyRoute(HybridRouteArgs args) {
    final navigator = navigatorKey.currentState;
    final resolver = _resolver;
    if (navigator == null || resolver == null) {
      _pendingRoute = args;
      return;
    }

    if (!resolver.isRegistered(args.routeName)) {
      unawaited(_notifyRouteNotFound(args));
      return;
    }

    _currentRouteName = args.routeName;
    _currentRequestId = args.requestId;

    // removeUntil=false 会清空旧栈，新栈深度恒为 1（canPop=false）。
    // 预先记录该预期值，避免随后 NavigatorObserver 产生一次重复的 canPopV2。
    _lastReportedCanPop = false;

    navigator.pushNamedAndRemoveUntil<void>(
      args.routeName,
      (Route<dynamic> route) => false,
      arguments: args,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_notifyRouteReady(args));
    });
  }

  void _handleSystemBack() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    // 宿主仅在 flutterCanPop == true 时下发 systemBackV2，此处直接出栈；
    // 出栈后的 canPop 变化由 NavigatorObserver 上报。
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _handleResetToBootstrap() {
    final navigator = navigatorKey.currentState;
    _pendingRoute = null;
    _currentRouteName = null;
    _currentRequestId = null;
    navigator?.pushNamedAndRemoveUntil<void>(
      HybridRouteNames.bootstrap,
      (Route<dynamic> route) => false,
    );
  }

  void _flushPendingRoute() {
    final pending = _pendingRoute;
    if (pending == null) return;
    _pendingRoute = null;
    _applyRoute(pending);
  }

  // MARK: - 上报辅助

  Future<void> _notifyFlutterReady() async {
    await _invoke(HybridOutboundMethods.flutterReady, <String, Object?>{
      'version': hybridProtocolVersion,
    });
  }

  Future<void> _notifyRouteReady(HybridRouteArgs args) async {
    final canPop = navigatorKey.currentState?.canPop() ?? false;
    _lastReportedCanPop = canPop;
    await _invoke(HybridOutboundMethods.routeReady, <String, Object?>{
      'version': hybridProtocolVersion,
      'requestId': args.requestId,
      'routeName': args.routeName,
      'path': args.path,
      'canPop': canPop,
    });
  }

  Future<void> _notifyRouteNotFound(HybridRouteArgs args) async {
    await _invoke(HybridOutboundMethods.routeNotFound, <String, Object?>{
      'version': hybridProtocolVersion,
      'requestId': args.requestId,
      'routeName': args.routeName,
      'path': args.path,
    });
  }

  Future<void> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await HybridChannels.routerV2.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 模块脱离宿主独立运行时通道不可用，忽略即可。
      debugPrint('[HybridGateway] channel unavailable: $method');
    } on PlatformException catch (error) {
      debugPrint('[HybridGateway] $method failed: ${error.code}');
    }
  }
}

/// 监听 Flutter 栈变化并同步 canPop 状态到宿主。
final class HybridNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleSync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleSync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _scheduleSync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _scheduleSync();

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(HybridGateway.instance.reportCanPop());
    });
  }
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map) {
    return value.map<String, dynamic>(
      (Object? key, Object? item) => MapEntry<String, dynamic>('$key', item),
    );
  }
  return const <String, dynamic>{};
}
