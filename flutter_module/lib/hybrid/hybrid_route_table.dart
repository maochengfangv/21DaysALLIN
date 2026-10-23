import 'package:flutter/material.dart';

import '../pages/auth_pages.dart';
import '../pages/channel_demo_pages.dart';
import '../pages/dio_demo_page.dart';
import '../pages/flutter_plugin_demo_page.dart';
import '../pages/platform_view_demo_page.dart';
import 'hybrid_gateway.dart';
import 'hybrid_route.dart';

/// Flutter 侧路由注册表。
///
/// routeName 与 iOS `RouteRegistry` 的注册项一一对应，
/// 承载「Native 下发 routeName → Flutter 页面」的解析与构造。
final class HybridRouteTable implements HybridRouteResolver {
  HybridRouteTable._();

  static final HybridRouteTable instance = HybridRouteTable._();

  static const Set<String> _registeredRouteNames = <String>{
    HybridRouteNames.bootstrap,
    HybridRouteNames.channelDemos,
    HybridRouteNames.methodChannelDemo,
    HybridRouteNames.eventChannelDemo,
    HybridRouteNames.basicMessageDemo,
    HybridRouteNames.platformViewDemo,
    HybridRouteNames.counterDemo,
    HybridRouteNames.userProfile,
    HybridRouteNames.login,
    HybridRouteNames.dioDemo,
    HybridRouteNames.flutterPluginDemo,
  };

  @override
  bool isRegistered(String routeName) =>
      _registeredRouteNames.contains(routeName);

  @override
  Route<void>? buildRoute(RouteSettings settings, HybridRouteArgs args) {
    final page = buildPage(args);
    if (page == null) return null;

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => page,
      fullscreenDialog:
          args.presentMode == HybridPresentMode.present ||
          args.animation == HybridAnimation.slideUp,
    );
  }

  /// 页面构造；未注册返回 null，由调用方决定兜底策略。
  Widget? buildPage(HybridRouteArgs args) {
    switch (args.routeName) {
      case HybridRouteNames.bootstrap:
        return const BootstrapPage();
      case HybridRouteNames.channelDemos:
        return ChannelDemoHomePage(
          navStyle: args.navStyle,
          source: args.paramString('from'),
        );
      case HybridRouteNames.methodChannelDemo:
        return MethodChannelDemoPage(navStyle: args.navStyle);
      case HybridRouteNames.eventChannelDemo:
        return EventChannelDemoPage(navStyle: args.navStyle);
      case HybridRouteNames.basicMessageDemo:
        return BasicMessageChannelDemoPage(navStyle: args.navStyle);
      case HybridRouteNames.platformViewDemo:
        return PlatformViewDemoPage(navStyle: args.navStyle);
      case HybridRouteNames.counterDemo:
        return CounterPage(
          navStyle: args.navStyle,
          from: args.paramString('from'),
        );
      case HybridRouteNames.userProfile:
        return UserProfilePage(navStyle: args.navStyle, args: args);
      case HybridRouteNames.login:
        return LoginPage(navStyle: args.navStyle, args: args);
      case HybridRouteNames.dioDemo:
        return DioDemoPage(navStyle: args.navStyle.name);
      case HybridRouteNames.flutterPluginDemo:
        return FlutterPluginDemoPage(navStyle: args.navStyle);
      default:
        return null;
    }
  }
}
