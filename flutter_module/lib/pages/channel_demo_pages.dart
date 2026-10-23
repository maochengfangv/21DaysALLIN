import 'dart:async';

import 'package:flutter/material.dart';

import '../hybrid/hybrid_channels.dart';
import '../hybrid/hybrid_gateway.dart';
import '../hybrid/hybrid_route.dart';
import 'demo_support.dart';

/// 容器复位占位页：Native 关闭 Flutter 容器后，Flutter 栈回到此处静默等待下一次 showRouteV2。
class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

class ChannelDemoHomePage extends StatelessWidget {
  const ChannelDemoHomePage({super.key, required this.navStyle, this.source});

  final NavStyle navStyle;
  final String? source;

  void _openDemo(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(
      routeName,
      arguments: HybridRouteArgs(
        routeName: routeName,
        navStyle: navStyle,
        params: <String, dynamic>{'from': HybridRouteNames.channelDemos},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'Channel Demos',
      navStyle: navStyle,
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
                    'Single FlutterEngine Add-to-App',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Current navStyle: ${navStyle.name}'),
                  Text('Opened from: ${source ?? 'unknown'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                _openDemo(context, HybridRouteNames.methodChannelDemo),
            child: const Text('Open MethodChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                _openDemo(context, HybridRouteNames.eventChannelDemo),
            child: const Text('Open EventChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                _openDemo(context, HybridRouteNames.basicMessageDemo),
            child: const Text('Open BasicMessageChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                _openDemo(context, HybridRouteNames.flutterPluginDemo),
            child: const Text('Open Plugin Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openDemo(context, HybridRouteNames.dioDemo),
            child: const Text('Open Dio Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                _openDemo(context, HybridRouteNames.platformViewDemo),
            child: const Text('Open PlatformView Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _openDemo(context, HybridRouteNames.counterDemo),
            child: const Text('Open Existing Counter Demo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => unawaited(
              HybridGateway.instance.openNative(
                routeName: 'native_page',
                params: <String, Object?>{
                  'from': 'flutter',
                  'ts': DateTime.now().toIso8601String(),
                },
              ),
            ),
            child: const Text('Open Native Page'),
          ),
        ],
      ),
    );
  }
}

class MethodChannelDemoPage extends StatefulWidget {
  const MethodChannelDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<MethodChannelDemoPage> createState() => _MethodChannelDemoPageState();
}

class _MethodChannelDemoPageState extends State<MethodChannelDemoPage> {
  final List<String> _logs = <String>[];

  Future<void> _invoke(String method) async {
    final response = await HybridChannels.method.invokeMethod<Object?>(method, {
      'requestId': createRequestId(method),
    });
    if (!mounted) return;
    setState(() {
      _logs.insert(0, prettyPrintPayload(response));
    });
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'MethodChannel Demo',
      navStyle: widget.navStyle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => _invoke('getDeviceInfo'),
                child: const Text('getDeviceInfo'),
              ),
              FilledButton(
                onPressed: () => _invoke('pickPhotoMock'),
                child: const Text('pickPhotoMock'),
              ),
              FilledButton(
                onPressed: () => _invoke('getLocationMock'),
                child: const Text('getLocationMock'),
              ),
              FilledButton(
                onPressed: () => _invoke('getScreenMetrics'),
                child: const Text('getScreenMetrics'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResultCard(
            title: 'Responses',
            content: _logs.isEmpty
                ? 'Tap a button to call iOS.'
                : _logs.join('\n\n'),
          ),
        ],
      ),
    );
  }
}

class EventChannelDemoPage extends StatefulWidget {
  const EventChannelDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<EventChannelDemoPage> createState() => _EventChannelDemoPageState();
}

class _EventChannelDemoPageState extends State<EventChannelDemoPage> {
  StreamSubscription<dynamic>? _subscription;
  final List<String> _events = <String>[];
  String _status = 'Idle';
  String _activeEvent = 'None';

  Future<void> _startListening(String eventName) async {
    await _subscription?.cancel();
    setState(() {
      _status = 'Listening';
      _activeEvent = eventName;
      _events.clear();
    });

    _subscription = HybridChannels.event
        .receiveBroadcastStream({'eventName': eventName})
        .listen(
          (dynamic event) {
            if (!mounted) return;
            setState(() {
              _events.insert(0, prettyPrintPayload(event));
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _status = 'Error';
              _events.insert(0, error.toString());
            });
          },
        );
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;
    setState(() {
      _status = 'Stopped';
      _activeEvent = 'None';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'EventChannel Demo',
      navStyle: widget.navStyle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $_status'),
                  const SizedBox(height: 4),
                  Text('Active source: $_activeEvent'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () => _startListening('sensorMock'),
                child: const Text('Start sensorMock'),
              ),
              FilledButton(
                onPressed: () => _startListening('notificationMock'),
                child: const Text('Start notificationMock'),
              ),
              OutlinedButton(
                onPressed: _stopListening,
                child: const Text('Stop listening'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResultCard(
            title: 'Event List',
            content: _events.isEmpty ? 'No events yet.' : _events.join('\n\n'),
          ),
        ],
      ),
    );
  }
}

class BasicMessageChannelDemoPage extends StatefulWidget {
  const BasicMessageChannelDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<BasicMessageChannelDemoPage> createState() =>
      _BasicMessageChannelDemoPageState();
}

class _BasicMessageChannelDemoPageState
    extends State<BasicMessageChannelDemoPage> {
  String _stringResponse = 'Tap a button to send a string message.';
  String _mapResponse = 'Tap a button to send a standard message.';

  Future<void> _sendStringMessage() async {
    final response = await HybridChannels.messageString.send(
      'Hello from Flutter at ${DateTime.now().toIso8601String()}',
    );
    if (!mounted) return;
    setState(() {
      _stringResponse = response ?? '(null)';
    });
  }

  Future<void> _sendStandardMessage() async {
    final payload = <String, Object?>{
      'requestId': createRequestId('standardMessage'),
      'message': 'Flutter map payload',
      'counter': 3,
      'items': const ['A', 'B', 'C'],
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await HybridChannels.messageStandard.send(payload);
    if (!mounted) return;
    setState(() {
      _mapResponse = prettyPrintPayload(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'BasicMessageChannel Demo',
      navStyle: widget.navStyle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _sendStringMessage,
                child: const Text('Send StringCodec'),
              ),
              FilledButton(
                onPressed: _sendStandardMessage,
                child: const Text('Send StandardMessageCodec'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResultCard(title: 'StringCodec Response', content: _stringResponse),
          const SizedBox(height: 12),
          ResultCard(
            title: 'StandardMessageCodec Response',
            content: _mapResponse,
          ),
        ],
      ),
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
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.from == null ? '' : 'from: ${widget.from}';

    return HybridPageScaffold(
      title: 'Counter $subtitle',
      navStyle: widget.navStyle,
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{
            'counter': _counter,
            'from': widget.from,
          },
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'counter: $_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() => _counter++),
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.route, required this.navStyle});

  final String route;
  final NavStyle navStyle;

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'Unknown Route',
      navStyle: navStyle,
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{'route': route, 'closed': true},
        ),
      ),
      child: Center(child: Text('Unknown route: $route')),
    );
  }
}
