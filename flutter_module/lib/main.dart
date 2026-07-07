import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_plugin/flutter_plugin.dart';

enum NavStyle { native, flutter, none }

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

class HybridChannelNames {
  static const router = 'com.example.hybrid/router';
  static const method = 'com.maocf.hybrid/method';
  static const event = 'com.maocf.hybrid/event';
  static const messageString = 'com.maocf.hybrid/message_string';
  static const messageStandard = 'com.maocf.hybrid/message_standard';
  static const platformViewControl = 'com.maocf.hybrid/platform_view_control';
  static const nativeViewType = 'com.maocf.hybrid/native_label_view';
}

class HybridChannels {
  static const router = MethodChannel(HybridChannelNames.router);
  static const method = MethodChannel(HybridChannelNames.method);
  static const event = EventChannel(HybridChannelNames.event);
  static const messageString = BasicMessageChannel<String>(
    HybridChannelNames.messageString,
    StringCodec(),
  );
  static const messageStandard = BasicMessageChannel<Object?>(
    HybridChannelNames.messageStandard,
    StandardMessageCodec(),
  );
  static const platformViewControl = MethodChannel(
    HybridChannelNames.platformViewControl,
  );
}

String createRequestId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

String prettyPrintPayload(Object? payload) {
  if (payload == null) return 'null';
  if (payload is Map || payload is List) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
  return payload.toString();
}

String colorToHex(Color color) {
  String hex(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${hex(color.alpha)}${hex(color.red)}${hex(color.green)}${hex(color.blue)}';
}

class DemoColorOption {
  const DemoColorOption(this.label, this.color);

  final String label;
  final Color color;
}

const List<DemoColorOption> backgroundColorOptions = <DemoColorOption>[
  DemoColorOption('Coral', Color(0xFFFF6B6B)),
  DemoColorOption('Ocean', Color(0xFF4D96FF)),
  DemoColorOption('Mint', Color(0xFF4ECDC4)),
  DemoColorOption('Amber', Color(0xFFFFC75F)),
  DemoColorOption('Violet', Color(0xFF845EC2)),
];

const List<DemoColorOption> textColorOptions = <DemoColorOption>[
  DemoColorOption('White', Colors.white),
  DemoColorOption('Black', Colors.black87),
  DemoColorOption('Navy', Color(0xFF1D3557)),
  DemoColorOption('Berry', Color(0xFFB5179E)),
];

Future<void> closeFlutterWithResult([Map<String, dynamic>? payload]) async {
  await HybridChannels.router.invokeMethod('closeFlutter', {
    'version': 1,
    'result': payload ?? const {'message': 'closed from flutter'},
  });
}

Future<void> openNativeSample() async {
  await HybridChannels.router.invokeMethod('openNative', {
    'version': 1,
    'route': 'native/sample',
    'params': {'from': 'flutter', 'ts': DateTime.now().toIso8601String()},
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runZonedGuarded(() {
    runApp(const HybridApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint('$stack');
  });
}

class HybridApp extends StatefulWidget {
  const HybridApp({super.key});

  @override
  State<HybridApp> createState() => _HybridAppState();
}

class _HybridAppState extends State<HybridApp> {
  final _navKey = GlobalKey<NavigatorState>();
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    HybridChannels.router.setMethodCallHandler(_onMethodCall);
    unawaited(
      HybridChannels.router.invokeMethod('flutterReady', {'version': 1}),
    );
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'pushRoute':
      case 'showRoute':
        return _showRoute(
          (call.arguments as Map?)?.cast<String, dynamic>() ?? const {},
        );
      case 'resetToBootstrap':
        return _resetToBootstrap();
      default:
        throw PlatformException(code: 'not_implemented', message: call.method);
    }
  }

  Future<void> _showRoute(Map<String, dynamic> args) async {
    final route = args['route'] as String? ?? '/';
    final params =
        (args['params'] as Map?)?.cast<String, dynamic>() ?? const {};
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
        HybridChannels.router.invokeMethod('routeReady', {
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
      title: 'Flutter Hybrid Demos',
      navigatorKey: _navKey,
      onGenerateRoute: (settings) {
        final args =
            (settings.arguments as Map?)?.cast<String, dynamic>() ?? const {};
        final params =
            (args['params'] as Map?)?.cast<String, dynamic>() ?? const {};
        final navStyle = navStyleFrom(
          args['navStyle'],
          fallback: NavStyle.flutter,
        );

        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(
              builder: (_) => BootstrapPage(
                isBootstrapping: _isBootstrapping,
                navStyle: navStyle,
              ),
              settings: settings,
            );
          case '/channel_demos':
            return MaterialPageRoute<void>(
              builder: (_) => ChannelDemoHomePage(
                navStyle: navStyle,
                source: params['from']?.toString(),
              ),
              settings: settings,
            );
          case '/channel_demos/method':
            return MaterialPageRoute<void>(
              builder: (_) => MethodChannelDemoPage(navStyle: navStyle),
              settings: settings,
            );
          case '/channel_demos/event':
            return MaterialPageRoute<void>(
              builder: (_) => EventChannelDemoPage(navStyle: navStyle),
              settings: settings,
            );
          case '/channel_demos/message':
            return MaterialPageRoute<void>(
              builder: (_) => BasicMessageChannelDemoPage(navStyle: navStyle),
              settings: settings,
            );
          case '/platform_view_demo':
            return MaterialPageRoute<void>(
              builder: (_) => PlatformViewDemoPage(navStyle: navStyle),
              settings: settings,
            );
          case '/counter':
            return MaterialPageRoute<void>(
              builder: (_) => CounterPage(
                from: params['from']?.toString(),
                navStyle: navStyle,
              ),
              settings: settings,
            );
          case '/plugin_demo/flutter_plugin':
            return MaterialPageRoute<void>(
              builder: (_) => FlutterPluginDemoPage(navStyle: navStyle),
              settings: settings,
            );
          default:
            return MaterialPageRoute<void>(
              builder: (_) => UnknownRoutePage(
                route: settings.name ?? '(null)',
                navStyle: navStyle,
              ),
              settings: settings,
            );
        }
      },
    );
  }
}

class BootstrapPage extends StatelessWidget {
  const BootstrapPage({
    super.key,
    required this.isBootstrapping,
    required this.navStyle,
  });

  final bool isBootstrapping;
  final NavStyle navStyle;

  @override
  Widget build(BuildContext context) {
    if (isBootstrapping) {
      return const Scaffold(body: SizedBox.expand());
    }
    return ChannelDemoHomePage(navStyle: navStyle);
  }
}

class HybridPageScaffold extends StatelessWidget {
  const HybridPageScaffold({
    super.key,
    required this.title,
    required this.navStyle,
    required this.child,
    this.canPop = false,
    this.onClose,
  });

  final String title;
  final NavStyle navStyle;
  final Widget child;
  final bool canPop;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final showInlineHeader = navStyle != NavStyle.flutter;
    Widget content = child;

    if (showInlineHeader) {
      content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (canPop)
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox(width: 64),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: onClose, child: const Text('Close')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      );
    }

    if (navStyle == NavStyle.none) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: navStyle == NavStyle.flutter
          ? AppBar(
              title: Text(title),
              actions: [
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            )
          : null,
      body: content,
    );
  }
}

class ChannelDemoHomePage extends StatelessWidget {
  const ChannelDemoHomePage({super.key, required this.navStyle, this.source});

  final NavStyle navStyle;
  final String? source;

  void _openDemo(BuildContext context, String route) {
    Navigator.of(
      context,
    ).pushNamed(route, arguments: {'navStyle': navStyle.name});
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'Channel Demos',
      navStyle: navStyle,
      onClose: () =>
          closeFlutterWithResult({'message': 'closed from demo home'}),
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
            onPressed: () => _openDemo(context, '/channel_demos/method'),
            child: const Text('Open MethodChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openDemo(context, '/channel_demos/event'),
            child: const Text('Open EventChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openDemo(context, '/channel_demos/message'),
            child: const Text('Open BasicMessageChannel Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openDemo(context, '/plugin_demo/flutter_plugin'),
            child: const Text('Open Plugin Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openDemo(context, '/platform_view_demo'),
            child: const Text('Open PlatformView Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _openDemo(context, '/counter'),
            child: const Text('Open Existing Counter Demo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: openNativeSample,
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
    final requestId = createRequestId(method);
    final response = await HybridChannels.method.invokeMethod<Object?>(method, {
      'requestId': requestId,
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
      canPop: true,
      onClose: () => closeFlutterWithResult({'demo': 'method', 'closed': true}),
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
      canPop: true,
      onClose: () => closeFlutterWithResult({'demo': 'event', 'closed': true}),
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
    final requestId = createRequestId('standardMessage');
    final payload = <String, Object?>{
      'requestId': requestId,
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
      canPop: true,
      onClose: () =>
          closeFlutterWithResult({'demo': 'message', 'closed': true}),
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

class PlatformViewDemoPage extends StatefulWidget {
  const PlatformViewDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<PlatformViewDemoPage> createState() => _PlatformViewDemoPageState();
}

class _PlatformViewDemoPageState extends State<PlatformViewDemoPage> {
  static const double _previewWidth = 320;
  static const double _previewHeight = 260;

  final TextEditingController _textController = TextEditingController(
    text: 'Hello from Flutter creationParams',
  );

  int? _platformViewId;
  double _nativeWidth = 220;
  double _nativeHeight = 120;
  double _cornerRadius = 16;
  bool _hidden = false;
  DemoColorOption _backgroundOption = backgroundColorOptions.first;
  DemoColorOption _textColorOption = textColorOptions.first;
  String _syncStatus = '等待 Native View 创建';

  Map<String, Object?> _buildNativeProps() {
    return <String, Object?>{
      'text': _textController.text,
      'width': _nativeWidth,
      'height': _nativeHeight,
      'cornerRadius': _cornerRadius,
      'backgroundColor': colorToHex(_backgroundOption.color),
      'textColor': colorToHex(_textColorOption.color),
      'hidden': _hidden,
    };
  }

  Future<void> _syncNativeView() async {
    final platformViewId = _platformViewId;
    if (platformViewId == null) {
      setState(() {
        _syncStatus = 'Native View 尚未创建';
      });
      return;
    }

    try {
      final response = await HybridChannels.platformViewControl
          .invokeMethod<Object?>('updateNativeView', <String, Object?>{
            'viewId': platformViewId,
            ..._buildNativeProps(),
          });

      if (!mounted) return;
      setState(() {
        _syncStatus = '最近一次同步成功\n${prettyPrintPayload(response)}';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '同步失败: ${error.code} ${error.message ?? ''}'.trim();
      });
    }
  }

  void _handlePlatformViewCreated(int viewId) {
    setState(() {
      _platformViewId = viewId;
      _syncStatus = 'Native View 已创建，viewId=$viewId';
    });
    unawaited(_syncNativeView());
  }

  void _resetState() {
    setState(() {
      _textController.text = 'Hello from Flutter creationParams';
      _nativeWidth = 220;
      _nativeHeight = 120;
      _cornerRadius = 16;
      _hidden = false;
      _backgroundOption = backgroundColorOptions.first;
      _textColorOption = textColorOptions.first;
    });
    unawaited(_syncNativeView());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildColorSelector({
    required String title,
    required List<DemoColorOption> options,
    required DemoColorOption selected,
    required ValueChanged<DemoColorOption> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((DemoColorOption option) {
            final isSelected = selected == option;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              avatar: CircleAvatar(backgroundColor: option.color),
              onSelected: (_) {
                onSelected(option);
                unawaited(_syncNativeView());
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title: ${value.toStringAsFixed(0)}$suffix'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (double nextValue) {
            onChanged(nextValue);
            unawaited(_syncNativeView());
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return HybridPageScaffold(
      title: 'PlatformView Demo',
      navStyle: widget.navStyle,
      canPop: true,
      onClose: () =>
          closeFlutterWithResult({'demo': 'platform_view', 'closed': true}),
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
                    'Flutter -> iOS Native View',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('初始属性通过 creationParams 传入；运行中通过 MethodChannel 更新。'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: _previewHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isIOS
                        ? Center(
                            child: SizedBox(
                              width: _previewWidth,
                              height: _previewHeight,
                              child: UiKitView(
                                viewType: HybridChannelNames.nativeViewType,
                                creationParams: _buildNativeProps(),
                                creationParamsCodec:
                                    const StandardMessageCodec(),
                                onPlatformViewCreated:
                                    _handlePlatformViewCreated,
                              ),
                            ),
                          )
                        : const Center(
                            child: Text('当前页面仅在 iOS 宿主中展示 Native PlatformView'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '动态控制面板',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Native UILabel 文本',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _syncNativeView,
                        icon: const Icon(Icons.send),
                      ),
                    ),
                    onSubmitted: (_) => _syncNativeView(),
                  ),
                  const SizedBox(height: 16),
                  _buildColorSelector(
                    title: '背景色',
                    options: backgroundColorOptions,
                    selected: _backgroundOption,
                    onSelected: (DemoColorOption option) {
                      setState(() {
                        _backgroundOption = option;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildColorSelector(
                    title: '文本颜色',
                    options: textColorOptions,
                    selected: _textColorOption,
                    onSelected: (DemoColorOption option) {
                      setState(() {
                        _textColorOption = option;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSlider(
                    title: 'Native 宽度',
                    value: _nativeWidth,
                    min: 120,
                    max: 280,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _nativeWidth = value;
                      });
                    },
                  ),
                  _buildSlider(
                    title: 'Native 高度',
                    value: _nativeHeight,
                    min: 60,
                    max: 180,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _nativeHeight = value;
                      });
                    },
                  ),
                  _buildSlider(
                    title: '圆角',
                    value: _cornerRadius,
                    min: 0,
                    max: 40,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _cornerRadius = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _hidden,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏 Native View'),
                    subtitle: const Text('通过 MethodChannel 同步 hidden 状态'),
                    onChanged: (bool value) {
                      setState(() {
                        _hidden = value;
                      });
                      unawaited(_syncNativeView());
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _syncNativeView,
                        child: const Text('同步到 iOS'),
                      ),
                      OutlinedButton(
                        onPressed: _resetState,
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ResultCard(title: '同步日志', content: _syncStatus),
        ],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(content),
          ],
        ),
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
      canPop: true,
      onClose: () =>
          closeFlutterWithResult({'counter': _counter, 'from': widget.from}),
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

class FlutterPluginDemoPage extends StatefulWidget {
  const FlutterPluginDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<FlutterPluginDemoPage> createState() => _FlutterPluginDemoPageState();
}

class _FlutterPluginDemoPageState extends State<FlutterPluginDemoPage> {
  final FlutterPluginApi _api = FlutterPluginApi();
  final TextEditingController _intervalController = TextEditingController(
    text: '1000',
  );

  StreamSubscription<Map<String, Object?>>? _eventSub;
  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];

  String _methodResult = '';
  String _eventControlResult = '';
  String _stringMessageResult = '';
  String _standardMessageResult = '';

  @override
  void initState() {
    super.initState();
    _eventSub = _api.eventStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, event);
        if (_events.length > 50) _events.removeLast();
      });
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, <String, Object?>{
          'eventName': 'error',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'payload': <String, Object?>{'error': error.toString()},
        });
      });
    });
  }

  @override
  void dispose() {
    unawaited(_api.stopTicking());
    unawaited(_eventSub?.cancel());
    _intervalController.dispose();
    super.dispose();
  }

  String _formatResult<T>(Result<T> r) {
    final dataText = prettyPrintPayload(r.data);
    return 'code=${r.code.code}(${r.code.name})\nmessage=${r.message}\nrequestId=${r.requestId}\ndata=$dataText';
  }

  Future<void> _callGetPlatformVersion() async {
    final r = await _api.getPlatformVersion();
    if (!mounted) return;
    setState(() => _methodResult = _formatResult(r));
  }

  Future<void> _callGetDeviceInfo() async {
    final r = await _api.getDeviceInfo();
    if (!mounted) return;
    setState(() => _methodResult = _formatResult(r));
  }

  Future<void> _callRequestCameraPermission() async {
    final r = await _api.requestCameraPermission();
    if (!mounted) return;
    setState(() => _methodResult = _formatResult(r));
  }

  Future<void> _startTicking() async {
    final interval = int.tryParse(_intervalController.text) ?? 1000;
    final r = await _api.startTicking(intervalMs: interval);
    if (!mounted) return;
    setState(() => _eventControlResult = _formatResult(r));
  }

  Future<void> _stopTicking() async {
    final r = await _api.stopTicking();
    if (!mounted) return;
    setState(() => _eventControlResult = _formatResult(r));
  }

  Future<void> _sendStringMessage() async {
    final r = await _api.sendStringMessage(text: 'hello from flutter');
    if (!mounted) return;
    setState(() => _stringMessageResult = _formatResult(r));
  }

  Future<void> _sendStandardMessage() async {
    final r = await _api.sendStandardMessage(
      payload: <String, Object?>{
        'text': 'hello',
        'number': 42,
        'bytes': Uint8List.fromList(<int>[9, 8, 7, 6]),
      },
    );
    if (!mounted) return;
    setState(() => _standardMessageResult = _formatResult(r));
  }

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'Plugin Demo',
      navStyle: widget.navStyle,
      canPop: true,
      onClose: () => closeFlutterWithResult({'demo': 'plugin_demo', 'closed': true}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MethodChannel', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _callGetPlatformVersion,
                        child: const Text('getPlatformVersion'),
                      ),
                      FilledButton(
                        onPressed: _callGetDeviceInfo,
                        child: const Text('getDeviceInfo'),
                      ),
                      FilledButton(
                        onPressed: _callRequestCameraPermission,
                        child: const Text('requestCameraPermission'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_methodResult.isEmpty ? 'No result yet' : _methodResult),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EventChannel', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'intervalMs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: _startTicking, child: const Text('Start')),
                      const SizedBox(width: 12),
                      OutlinedButton(onPressed: _stopTicking, child: const Text('Stop')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_eventControlResult.isEmpty ? 'No control result yet' : _eventControlResult),
                  const SizedBox(height: 12),
                  Text('Events (${_events.length})', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final text = prettyPrintPayload(_events[index]);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(text),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BasicMessageChannel', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _sendStringMessage,
                        child: const Text('StringCodec'),
                      ),
                      FilledButton(
                        onPressed: _sendStandardMessage,
                        child: const Text('StandardCodec'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('StringCodec Result', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SelectableText(
                    _stringMessageResult.isEmpty ? 'No result yet' : _stringMessageResult,
                  ),
                  const SizedBox(height: 12),
                  Text('StandardCodec Result', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SelectableText(
                    _standardMessageResult.isEmpty ? 'No result yet' : _standardMessageResult,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({
    super.key,
    required this.route,
    required this.navStyle,
  });

  final String route;
  final NavStyle navStyle;

  @override
  Widget build(BuildContext context) {
    return HybridPageScaffold(
      title: 'Unknown Route',
      navStyle: navStyle,
      onClose: () => closeFlutterWithResult({'route': route, 'closed': true}),
      child: Center(child: Text('Unknown route: $route')),
    );
  }
}
