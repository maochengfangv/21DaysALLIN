import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_plugin/flutter_plugin.dart';

import '../hybrid/hybrid_gateway.dart';
import '../hybrid/hybrid_route.dart';
import 'demo_support.dart';

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
    _eventSub = _api.eventStream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) _events.removeLast();
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _events.insert(0, <String, Object?>{
            'eventName': 'error',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'payload': <String, Object?>{'error': error.toString()},
          });
        });
      },
    );
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
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{'demo': 'plugin_demo', 'closed': true},
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
                    'MethodChannel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                  SelectableText(
                    _methodResult.isEmpty ? 'No result yet' : _methodResult,
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
                    'EventChannel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                      FilledButton(
                        onPressed: _startTicking,
                        child: const Text('Start'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _stopTicking,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _eventControlResult.isEmpty
                        ? 'No control result yet'
                        : _eventControlResult,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Events (${_events.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(prettyPrintPayload(_events[index])),
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
                  Text(
                    'BasicMessageChannel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                  Text(
                    'StringCodec Result',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _stringMessageResult.isEmpty
                        ? 'No result yet'
                        : _stringMessageResult,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'StandardCodec Result',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _standardMessageResult.isEmpty
                        ? 'No result yet'
                        : _standardMessageResult,
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
