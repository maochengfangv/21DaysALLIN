import 'dart:async';

import 'package:flutter/material.dart';

import 'env/app_env.dart';
import 'hybrid/hybrid_gateway.dart';
import 'hybrid/hybrid_route.dart';
import 'hybrid/hybrid_route_table.dart';
import 'pages/channel_demo_pages.dart';
import 'ui/loading/loading_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // 混合路由网关装配：安装 Native → Flutter 方法处理器并注入路由注册表。
  // 必须在 runApp 之前完成，避免丢失宿主下发的首帧路由指令。
  HybridGateway.instance.bootstrap(resolver: HybridRouteTable.instance);

  runZonedGuarded(
    () {
      runApp(const HybridApp());
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error');
      debugPrint('$stack');
    },
  );
}

/// 混合工程壳：仅负责装配路由表与网关，业务页面由 `HybridRouteTable` 提供。
class HybridApp extends StatelessWidget {
  const HybridApp({super.key});

  @override
  Widget build(BuildContext context) {
    final gateway = HybridGateway.instance;

    return MaterialApp(
      title: 'Flutter Hybrid Demos',
      navigatorKey: gateway.navigatorKey,
      navigatorObservers: <NavigatorObserver>[gateway.navigatorObserver],
      initialRoute: HybridRouteNames.bootstrap,
      builder: (context, child) {
        return LoadingOverlay(child: child ?? const SizedBox.expand());
      },
      onGenerateRoute: (settings) {
        final args = HybridRouteArgs.from(
          settings.arguments,
          fallbackRouteName: settings.name,
        );
        return HybridRouteTable.instance.buildRoute(settings, args);
      },
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => UnknownRoutePage(
          route: settings.name ?? '(null)',
          navStyle: NavStyle.flutter,
        ),
      ),
    );
  }
}
