import 'dart:async';

import 'package:flutter/material.dart';

import '../hybrid/hybrid_gateway.dart';
import '../hybrid/hybrid_route.dart';
import 'demo_support.dart';

/// 登录兜底页：宿主在 needLogin 校验失败时下发 login 路由，
/// Flutter 侧完成登录后回传结果，宿主据此恢复原始路由。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.navStyle, required this.args});

  final NavStyle navStyle;
  final HybridRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final redirectRoute = args.paramString('redirectRoute') ?? '(none)';
    final redirectParams = prettyPrintPayload(args.params['redirectParams']);

    return HybridPageScaffold(
      title: 'Login',
      navStyle: navStyle,
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: const <String, Object?>{'loggedIn': false},
          cancelled: true,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '登录后可继续访问',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('redirectRoute: $redirectRoute'),
                  const SizedBox(height: 4),
                  Text('redirectParams: $redirectParams'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => unawaited(
              HybridGateway.instance.closeFlutter(
                result: const <String, Object?>{'loggedIn': true},
              ),
            ),
            child: const Text('模拟登录成功'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => unawaited(
              HybridGateway.instance.closeFlutter(
                result: const <String, Object?>{'loggedIn': false},
                cancelled: true,
              ),
            ),
            child: const Text('取消登录'),
          ),
        ],
      ),
    );
  }
}

/// 需登录的个人中心页。
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.navStyle, required this.args});

  final NavStyle navStyle;
  final HybridRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final userId = args.paramString('userId') ?? '(unknown)';

    return HybridPageScaffold(
      title: 'User Profile',
      navStyle: navStyle,
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{'userId': userId, 'closed': true},
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'userId: $userId',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('params: ${prettyPrintPayload(args.params)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => unawaited(
              HybridGateway.instance.closeFlutter(
                result: <String, Object?>{
                  'userId': userId,
                  'action': 'profile_confirmed',
                },
              ),
            ),
            child: const Text('回传结果并关闭'),
          ),
        ],
      ),
    );
  }
}
