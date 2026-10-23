import 'package:flutter/widgets.dart';

/// V2 路由协议版本号，与 iOS `RouteMeta.version` 对齐。
const int hybridProtocolVersion = 2;

/// V2 路由通道的方法名（Native → Flutter）。
final class HybridInboundMethods {
  HybridInboundMethods._();

  /// Native 下发路由：打开指定 routeName。
  static const String showRoute = 'showRouteV2';

  /// Native 触发返回（导航栏返回 / 侧滑被宿主拦截）。
  static const String systemBack = 'systemBackV2';

  /// Native 关闭容器后，要求 Flutter 栈复位到 bootstrap。
  static const String resetToBootstrap = 'resetToBootstrapV2';
}

/// V2 路由通道的方法名（Flutter → Native）。
final class HybridOutboundMethods {
  HybridOutboundMethods._();

  /// Flutter 侧通道就绪。
  static const String flutterReady = 'flutterReadyV2';

  /// 目标路由已完成渲染（Native 据此结束 loading / pop 兜底页）。
  static const String routeReady = 'routeReadyV2';

  /// routeName 未注册，交由 Native 走 route_error 兜底。
  static const String routeNotFound = 'routeNotFoundV2';

  /// Flutter → Native 跳转。
  static const String openNative = 'openNativeV2';

  /// Flutter 主动关闭整个容器并回传结果。
  static const String closeFlutter = 'closeFlutterV2';

  /// Flutter 栈深度变化上报（决定宿主返回事件的分流方向）。
  static const String canPop = 'canPopV2';
}

/// Flutter 侧已注册的 routeName，需与 iOS `RouteRegistry` 注册表保持一致。
final class HybridRouteNames {
  HybridRouteNames._();

  /// 容器复位占位页（Native 可见性为空白，仅用于承接 reset）。
  static const String bootstrap = '__bootstrap__';

  static const String channelDemos = 'channel_demos';
  static const String methodChannelDemo = 'method_channel_demo';
  static const String eventChannelDemo = 'event_channel_demo';
  static const String basicMessageDemo = 'basic_message_demo';
  static const String platformViewDemo = 'platform_view_demo';
  static const String counterDemo = 'counter_demo';
  static const String userProfile = 'user_profile';
  static const String login = 'login';

  /// 以下为 Flutter 内部导航路由（不由 Native 直接下发）。
  static const String dioDemo = 'dio_demo';
  static const String flutterPluginDemo = 'flutter_plugin_demo';
}

/// 导航栏归属：决定 AppBar 由 Native 还是 Flutter 提供。
enum NavStyle { native, flutter, none }

NavStyle navStyleFrom(dynamic value, {NavStyle fallback = NavStyle.flutter}) {
  switch (value?.toString()) {
    case 'native':
      return NavStyle.native;
    case 'flutter':
      return NavStyle.flutter;
    case 'none':
      return NavStyle.none;
    default:
      return fallback;
  }
}

/// 容器呈现方式，与 iOS `RoutePresentMode` 对齐。
enum HybridPresentMode { push, present, replace }

HybridPresentMode hybridPresentModeFrom(dynamic value) {
  switch (value?.toString()) {
    case 'present':
      return HybridPresentMode.present;
    case 'replace':
      return HybridPresentMode.replace;
    default:
      return HybridPresentMode.push;
  }
}

/// 转场动画，与 iOS `RouteAnimation` 对齐。
enum HybridAnimation { platform, none, fade, slideLeft, slideUp }

HybridAnimation hybridAnimationFrom(dynamic value) {
  switch (value?.toString()) {
    case 'none':
      return HybridAnimation.none;
    case 'fade':
      return HybridAnimation.fade;
    case 'slideLeft':
      return HybridAnimation.slideLeft;
    case 'slideUp':
      return HybridAnimation.slideUp;
    default:
      return HybridAnimation.platform;
  }
}

/// Native 下发 / Flutter 内部传递的统一路由参数对象。
@immutable
final class HybridRouteArgs {
  const HybridRouteArgs({
    required this.routeName,
    this.requestId,
    this.path,
    this.params = const <String, dynamic>{},
    this.navStyle = NavStyle.flutter,
    this.pageId,
    this.presentMode = HybridPresentMode.push,
    this.animation = HybridAnimation.platform,
    this.isFirstEnter = false,
  });

  /// 由 Native 下发的原始参数构造。
  factory HybridRouteArgs.fromNative(Map<String, dynamic> raw) {
    return HybridRouteArgs(
      routeName: raw['routeName'] as String? ?? HybridRouteNames.bootstrap,
      requestId: raw['requestId'] as String?,
      path: raw['path'] as String?,
      params: _asStringMap(raw['params']),
      navStyle: navStyleFrom(raw['navStyle']),
      pageId: raw['pageId'] as String?,
      presentMode: hybridPresentModeFrom(raw['presentMode']),
      animation: hybridAnimationFrom(raw['animation']),
      isFirstEnter: raw['isFirstEnter'] as bool? ?? false,
    );
  }

  /// 由 `RouteSettings.arguments` 归一化构造，兼容桥接下发与 Flutter 内部 push。
  factory HybridRouteArgs.from(Object? arguments, {String? fallbackRouteName}) {
    if (arguments is HybridRouteArgs) return arguments;
    final routeName = fallbackRouteName ?? HybridRouteNames.bootstrap;
    if (arguments is Map) {
      final raw = _asStringMap(arguments);
      return HybridRouteArgs.fromNative(<String, dynamic>{
        ...raw,
        'routeName': raw['routeName'] ?? routeName,
        'params': raw['params'] ?? raw,
      });
    }
    return HybridRouteArgs(routeName: routeName);
  }

  final String routeName;
  final String? requestId;
  final String? path;
  final Map<String, dynamic> params;
  final NavStyle navStyle;
  final String? pageId;
  final HybridPresentMode presentMode;
  final HybridAnimation animation;
  final bool isFirstEnter;

  String? paramString(String key) => params[key]?.toString();
}

/// Flutter 回传宿主的路由结果。
@immutable
final class HybridRouteResult {
  const HybridRouteResult({
    required this.routeName,
    this.requestId,
    this.payload,
    this.cancelled = false,
  });

  final String routeName;
  final String? requestId;
  final Object? payload;
  final bool cancelled;
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is Map) {
    return value.map<String, dynamic>(
      (Object? key, Object? item) => MapEntry<String, dynamic>('$key', item),
    );
  }
  return const <String, dynamic>{};
}
