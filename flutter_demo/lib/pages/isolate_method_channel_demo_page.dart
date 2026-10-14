import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('demo/isolate_method_channel');

int _heavyChecksum(int rounds) {
  var value = 0;
  for (var i = 0; i < rounds; i++) {
    value = (value + (i * 31) ^ (i >> 3)) % 1000000007;
  }
  return value;
}

Future<void> _workerEntry(SendPort hostPort) async {
  final workerPort = ReceivePort();
  hostPort.send(<String, Object?>{
    'type': 'worker_ready',
    'workerPort': workerPort.sendPort,
  });

  await for (final message in workerPort) {
    if (message is! Map) continue;
    final type = message['type'];

    if (type == 'start') {
      final requestId = message['requestId'] as int? ?? 0;
      final rounds = message['rounds'] as int? ?? 3000000;

      final checksum = _heavyChecksum(rounds);
      final nativeReplyPort = ReceivePort();

      hostPort.send(<String, Object?>{
        'type': 'native_request',
        'requestId': requestId,
        'replyPort': nativeReplyPort.sendPort,
        'message': '来自子 Isolate，checksum=$checksum，rounds=$rounds',
      });

      final nativeResult = await nativeReplyPort.first;
      nativeReplyPort.close();

      hostPort.send(<String, Object?>{
        'type': 'worker_done',
        'requestId': requestId,
        'checksum': checksum,
        'rounds': rounds,
        'nativeResult': nativeResult,
      });
    }

    if (type == 'stop') {
      workerPort.close();
      break;
    }
  }
}

class IsolateMethodChannelDemoPage extends StatefulWidget {
  const IsolateMethodChannelDemoPage({super.key});

  static const routeName = '/isolate-method-channel-demo';

  @override
  State<IsolateMethodChannelDemoPage> createState() =>
      _IsolateMethodChannelDemoPageState();
}

class _IsolateMethodChannelDemoPageState
    extends State<IsolateMethodChannelDemoPage> {
  final List<String> _logs = <String>[];

  ReceivePort? _mainReceivePort;
  StreamSubscription<dynamic>? _mainSubscription;
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;

  bool _booting = false;
  bool _running = false;
  int _requestId = 0;
  String _status = '未启动';
  Map<Object?, Object?>? _lastNativeResult;
  int? _lastChecksum;

  @override
  void dispose() {
    _shutdownWorker();
    super.dispose();
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');

    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[$hh:$mm:$ss] $message');
      if (_logs.length > 12) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _ensureWorkerStarted() async {
    if (_workerSendPort != null || _booting) return;

    _booting = true;
    _appendLog('开始启动子 Isolate');
    setState(() => _status = '启动子 Isolate 中...');

    final receivePort = ReceivePort();
    _mainReceivePort = receivePort;

    _mainSubscription = receivePort.listen((dynamic message) async {
      if (message is! Map) return;

      final type = message['type'];

      if (type == 'worker_ready') {
        final workerPort = message['workerPort'];
        if (workerPort is SendPort && mounted) {
          setState(() {
            _workerSendPort = workerPort;
            _status = '子 Isolate 已就绪';
          });
          _appendLog('子 Isolate 已建立双向通信');
        }
        return;
      }

      if (type == 'native_request') {
        final replyPort = message['replyPort'];
        final requestId = message['requestId'];
        final workerMessage = '${message['message'] ?? ''}';

        _appendLog('主 Isolate 收到 requestId=$requestId，准备调用 MethodChannel');

        try {
          final result = await _channel.invokeMethod<Object>(
            'nativeEcho',
            <String, Object?>{
              'message': workerMessage,
            },
          );

          final sendableResult = result is Map
              ? Map<Object?, Object?>.from(result)
              : <Object?, Object?>{'raw': result};

          if (replyPort is SendPort) {
            replyPort.send(sendableResult);
          }

          _appendLog('主 Isolate 已拿到原生结果，并回传给子 Isolate');
        } on PlatformException catch (error) {
          if (replyPort is SendPort) {
            replyPort.send(<Object?, Object?>{
              'error': error.message ?? error.code,
            });
          }
          _appendLog('MethodChannel 调用失败: ${error.message ?? error.code}');
        }
        return;
      }

      if (type == 'worker_done' && mounted) {
        final nativeResult = message['nativeResult'];
        setState(() {
          _running = false;
          _status = '完整闭环已完成';
          _lastChecksum = message['checksum'] as int?;
          _lastNativeResult = nativeResult is Map
              ? Map<Object?, Object?>.from(nativeResult)
              : <Object?, Object?>{'raw': nativeResult};
        });
        _appendLog('子 Isolate 收到主 Isolate 回传的原生结果，闭环结束');
      }
    });

    _workerIsolate = await Isolate.spawn<SendPort>(
      _workerEntry,
      receivePort.sendPort,
      debugName: 'isolate-method-channel-demo-worker',
    );

    _booting = false;
  }

  void _shutdownWorker() {
    _workerSendPort?.send(<String, Object?>{'type': 'stop'});
    _workerSendPort = null;
    _mainSubscription?.cancel();
    _mainSubscription = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }

  Future<void> _runDemo() async {
    if (_running) return;

    await _ensureWorkerStarted();
    if (_workerSendPort == null || !mounted) return;

    final currentRequestId = ++_requestId;

    setState(() {
      _running = true;
      _status = '子 Isolate 计算中 -> 主 Isolate 代理调原生';
      _lastNativeResult = null;
      _lastChecksum = null;
    });

    _appendLog('发送 start 指令给子 Isolate');
    _workerSendPort!.send(<String, Object?>{
      'type': 'start',
      'requestId': currentRequestId,
      'rounds': 3500000,
    });
  }

  Widget _kv(String title, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final native = _lastNativeResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Isolate -> MethodChannel 闭环 Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '目标链路：子 Isolate 先做计算，然后通过 SendPort 把“调用原生”的请求发回主 Isolate；'
                '主 Isolate 再通过 MethodChannel 调原生，最后把结果回传给子 Isolate。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _running ? null : _runDemo,
            child: const Text('运行最小闭环'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _shutdownWorker();
              setState(() {
                _running = false;
                _status = '已停止';
              });
              _appendLog('手动停止 worker');
            },
            child: const Text('停止 Worker'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _kv('当前状态', _status),
                  _kv('最近 checksum', '${_lastChecksum ?? '暂无'}'),
                  _kv('原生返回 from', '${native?['from'] ?? '暂无'}'),
                  _kv('原生返回 echo', '${native?['echo'] ?? '暂无'}'),
                  _kv('原生执行线程', '${native?['thread'] ?? '暂无'}'),
                  _kv('原生时间戳', '${native?['timestamp'] ?? '暂无'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '运行日志',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_logs.isEmpty)
                    const Text('暂无日志')
                  else
                    for (final log in _logs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(log),
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
