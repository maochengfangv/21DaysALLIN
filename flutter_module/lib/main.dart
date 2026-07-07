import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum NavStyle {
  native,
  flutter,
  none,
}

NavStyle navStyleFrom(dynamic value, {NavStyle fallback = NavStyle.flutter}) {
  final raw = value?.toString();
  switch (raw) {
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HybridApp());
}

class HybridApp extends StatefulWidget {
  const HybridApp({super.key});

  @override
  State<HybridApp> createState() => _HybridAppState();
}

class _HybridAppState extends State<HybridApp> {
  static const _channel = MethodChannel('com.example.hybrid/router');

  final _navKey = GlobalKey<NavigatorState>();
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onMethodCall);
    unawaited(_channel.invokeMethod('flutterReady', {'version': 1}));
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'pushRoute':
      case 'showRoute':
        return _showRoute((call.arguments as Map?)?.cast<String, dynamic>() ?? const {});
      case 'resetToBootstrap':
        return _resetToBootstrap();
      default:
        throw PlatformException(code: 'not_implemented', message: call.method);
    }
  }

  Future<void> _showRoute(Map<String, dynamic> args) async {
    final route = args['route'] as String? ?? '/';
    final params = (args['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    final navStyle = args['navStyle'];
    final requestId = args['requestId'];

    final navigator = _navKey.currentState;
    if (navigator == null) return;

    if (mounted) {
      setState(() => _isBootstrapping = false);
    }

    navigator.pushNamedAndRemoveUntil(
      route,
      (_) => false,
      arguments: {'params': params, 'navStyle': navStyle},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _channel.invokeMethod('routeReady', {
          'version': 1,
          'route': route,
          'requestId': requestId,
        }),
      );
    });
  }

  Future<void> _resetToBootstrap() async {
    final navigator = _navKey.currentState;
    if (navigator == null) return;

    if (mounted) {
      setState(() => _isBootstrapping = true);
    }

    navigator.pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Module',
      navigatorKey: _navKey,
      onGenerateRoute: (settings) {
        final args = (settings.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        final params = (args['params'] as Map?)?.cast<String, dynamic>() ?? const {};
        final navStyle = navStyleFrom(args['navStyle'], fallback: NavStyle.flutter);

        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(
              builder: (_) => BootstrapPage(
                isBootstrapping: _isBootstrapping,
                navStyle: navStyle,
              ),
            );
          case '/counter':
            final from = params['from']?.toString();
            return MaterialPageRoute<void>(
              builder: (_) => CounterPage(from: from, navStyle: navStyle),
              settings: settings,
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => UnknownRoutePage(route: settings.name ?? '(null)', navStyle: navStyle),
              settings: settings,
            );
        }
      },
    );
  }
}

class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key, required this.isBootstrapping, required this.navStyle});

  final bool isBootstrapping;
  final NavStyle navStyle;

  @override
  Widget build(BuildContext context) {
    if (isBootstrapping) {
      return const Scaffold(body: SizedBox.expand());
    }
    return FlutterRootPage(navStyle: navStyle);
  }
}

class FlutterRootPage extends StatelessWidget {
  const FlutterRootPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  static const _channel = MethodChannel('com.example.hybrid/router');

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/counter', arguments: {
                'params': {'from': 'flutter'},
                'navStyle': navStyle.name,
              });
            },
            child: const Text('Push /counter'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await _channel.invokeMethod('openNative', {
                'version': 1,
                'route': 'native/sample',
                'params': {'from': 'flutter', 'ts': DateTime.now().toIso8601String()},
              });
            },
            child: const Text('Open Native Page'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () async {
              await _channel.invokeMethod('closeFlutter', {
                'version': 1,
                'result': {'message': 'closed from flutter root'},
              });
            },
            child: const Text('Close Flutter (with result)'),
          ),
        ],
      ),
    );

    if (navStyle == NavStyle.none) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: navStyle == NavStyle.flutter ? AppBar(title: const Text('Flutter Root')) : null,
      body: content,
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key, this.from, required this.navStyle});

  final String? from;
  final NavStyle navStyle;

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  static const _channel = MethodChannel('com.example.hybrid/router');

  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.from == null ? '' : 'from: ${widget.from}';

    Widget content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('counter: $_counter', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(() => _counter++),
            child: const Text('Increment'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () async {
              await _channel.invokeMethod('closeFlutter', {
                'version': 1,
                'result': {'counter': _counter, 'from': widget.from},
              });
            },
            child: const Text('Close Flutter (with result)'),
          ),
        ],
      ),
    );

    if (widget.navStyle == NavStyle.none) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: widget.navStyle == NavStyle.flutter
          ? AppBar(
              title: Text('Counter $subtitle'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await _channel.invokeMethod('closeFlutter', {
                    'version': 1,
                    'result': {'counter': _counter, 'from': widget.from},
                  });
                },
              ),
            )
          : null,
      body: content,
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.route, required this.navStyle});

  final String route;
  final NavStyle navStyle;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(child: Text('Unknown route: $route'));

    if (navStyle == NavStyle.none) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: navStyle == NavStyle.flutter ? AppBar(title: const Text('Unknown Route')) : null,
      body: content,
    );
  }
}
