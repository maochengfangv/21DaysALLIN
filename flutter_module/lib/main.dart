import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onMethodCall);
    unawaited(_channel.invokeMethod('flutterReady', {'version': 1}));
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'pushRoute':
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        final route = args['route'] as String? ?? '/';
        final params = (args['params'] as Map?)?.cast<String, dynamic>() ?? const {};

        final navigator = _navKey.currentState;
        if (navigator == null) return null;

        if (route == '/') {
          navigator.popUntil((r) => r.isFirst);
          return null;
        }

        navigator.pushNamed(route, arguments: params);
        return null;

      default:
        throw PlatformException(code: 'not_implemented', message: call.method);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Module',
      navigatorKey: _navKey,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(builder: (_) => const FlutterRootPage());
          case '/counter':
            final params = (settings.arguments as Map?)?.cast<String, dynamic>() ?? const {};
            final from = params['from']?.toString();
            return MaterialPageRoute<void>(
              builder: (_) => CounterPage(from: from),
              settings: settings,
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => UnknownRoutePage(route: settings.name ?? '(null)'),
              settings: settings,
            );
        }
      },
    );
  }
}

class FlutterRootPage extends StatelessWidget {
  const FlutterRootPage({super.key});

  static const _channel = MethodChannel('com.example.hybrid/router');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Root')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/counter', arguments: {'from': 'flutter'});
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
      ),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key, this.from});

  final String? from;

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  static const _channel = MethodChannel('com.example.hybrid/router');

  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.from == null ? '' : 'from: ${widget.from}';

    return Scaffold(
      appBar: AppBar(title: Text('Counter $subtitle')),
      body: Center(
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
      ),
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unknown Route')),
      body: Center(child: Text('Unknown route: $route')),
    );
  }
}
