import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const int _checksumMod = 1000000007;

bool _isPrime(int value) {
  if (value < 2) return false;
  if (value == 2) return true;
  if (value.isEven) return false;

  final limit = math.sqrt(value).floor();
  for (int factor = 3; factor <= limit; factor += 2) {
    if (value % factor == 0) {
      return false;
    }
  }
  return true;
}

Map<String, Object> _countPrimesPayload(int upperBound) {
  final stopwatch = Stopwatch()..start();
  var primeCount = 0;
  var checksum = 0;

  for (var number = 2; number <= upperBound; number++) {
    if (_isPrime(number)) {
      primeCount++;
      checksum = (checksum + number) % _checksumMod;
    }
  }

  stopwatch.stop();
  return <String, Object>{
    'upperBound': upperBound,
    'primeCount': primeCount,
    'checksum': checksum,
    'elapsedMs': stopwatch.elapsedMilliseconds,
  };
}

void _primeWorker(List<Object> args) {
  final sendPort = args[0] as SendPort;
  final upperBound = args[1] as int;
  final stopwatch = Stopwatch()..start();

  var primeCount = 0;
  var checksum = 0;
  final progressStep = math.max(1000, upperBound ~/ 20);

  for (var number = 2; number <= upperBound; number++) {
    if (_isPrime(number)) {
      primeCount++;
      checksum = (checksum + number) % _checksumMod;
    }

    if (number % progressStep == 0 || number == upperBound) {
      sendPort.send(<String, Object>{
        'type': 'progress',
        'progress': number / upperBound,
        'current': number,
      });
    }
  }

  stopwatch.stop();
  sendPort.send(<String, Object>{
    'type': 'done',
    'upperBound': upperBound,
    'primeCount': primeCount,
    'checksum': checksum,
    'elapsedMs': stopwatch.elapsedMilliseconds,
  });
}

void _lifecycleHeartbeatWorker(SendPort sendPort) {
  var tick = 0;
  Timer.periodic(const Duration(seconds: 1), (_) {
    tick++;
    sendPort.send(<String, Object>{
      'type': 'heartbeat',
      'tick': tick,
      'sentAt': DateTime.now().toIso8601String(),
    });
  });
}

class ThreadDemoPage extends StatefulWidget {
  static const routeName = '/thread-demo';

  const ThreadDemoPage({super.key});

  @override
  State<ThreadDemoPage> createState() => _ThreadDemoPageState();
}

class _ThreadDemoPageState extends State<ThreadDemoPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<int> _workloads = <int>[120000, 220000, 320000];

  late final AnimationController _pulseController;

  int _selectedWorkload = _workloads[1];
  bool _isRunning = false;
  bool _hasProgress = false;
  double _progress = 0;
  String _lastStrategy = '未执行';
  String _status = '点击下方按钮开始实验';
  Map<String, Object>? _lastResult;
  final List<String> _logs = <String>[];

  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _workerSubscription;
  Isolate? _workerIsolate;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _lifecycleScenarioRunning = false;
  int _mainIsolateTick = 0;
  int _workerHeartbeatTick = 0;
  String _lastWorkerHeartbeatAt = '未收到';
  DateTime? _lastLifecycleChangedAt;
  Timer? _mainIsolateTimer;
  ReceivePort? _lifecycleReceivePort;
  StreamSubscription<dynamic>? _lifecycleSubscription;
  Isolate? _lifecycleIsolate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardownWorker();
    _teardownLifecycleScenario();
    _pulseController.dispose();
    super.dispose();
  }

  void _teardownWorker() {
    _workerSubscription?.cancel();
    _workerSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }

  void _teardownLifecycleScenario() {
    _mainIsolateTimer?.cancel();
    _mainIsolateTimer = null;
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    _lifecycleReceivePort?.close();
    _lifecycleReceivePort = null;
    _lifecycleIsolate?.kill(priority: Isolate.immediate);
    _lifecycleIsolate = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _lifecycleState = state;
      _lastLifecycleChangedAt = DateTime.now();
    });
    _addLog('生命周期切换 -> $state');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '未记录';
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _startLifecycleScenario() async {
    if (_lifecycleScenarioRunning) return;
    _teardownLifecycleScenario();

    setState(() {
      _lifecycleScenarioRunning = true;
      _mainIsolateTick = 0;
      _workerHeartbeatTick = 0;
      _lastWorkerHeartbeatAt = '未收到';
    });

    _mainIsolateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _mainIsolateTick++);
    });

    final receivePort = ReceivePort();
    _lifecycleReceivePort = receivePort;
    _lifecycleSubscription = receivePort.listen((dynamic message) {
      if (!mounted || message is! Map) return;
      if (message['type'] == 'heartbeat') {
        setState(() {
          _workerHeartbeatTick = (message['tick'] as num).toInt();
          _lastWorkerHeartbeatAt = '${message['sentAt']}';
        });
      }
    });

    _lifecycleIsolate = await Isolate.spawn<SendPort>(
      _lifecycleHeartbeatWorker,
      receivePort.sendPort,
      debugName: 'lifecycle-heartbeat',
    );

    _addLog('已启动前后台切换观测场景');
  }

  void _stopLifecycleScenario() {
    if (!_lifecycleScenarioRunning) return;
    _teardownLifecycleScenario();
    setState(() => _lifecycleScenarioRunning = false);
    _addLog('已停止前后台切换观测场景');
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');

    setState(() {
      _logs.insert(0, '[$hh:$mm:$ss] $message');
      if (_logs.length > 6) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _runOnMainIsolate() async {
    if (_isRunning) return;

    _teardownWorker();
    setState(() {
      _isRunning = true;
      _hasProgress = false;
      _progress = 0;
      _lastStrategy = '主 isolate 同步计算';
      _status = '准备在主 isolate 上做大计算，旋转球会卡住';
    });
    _addLog('开始主 isolate 同步计算');

    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final wallClock = Stopwatch()..start();
      final result = _countPrimesPayload(_selectedWorkload);
      wallClock.stop();

      if (!mounted) return;

      final merged = <String, Object>{
        ...result,
        'wallClockMs': wallClock.elapsedMilliseconds,
      };

      setState(() {
        _isRunning = false;
        _progress = 1;
        _lastResult = merged;
        _status = '主 isolate 被阻塞期间，动画与输入都会停顿';
      });
      _addLog('主 isolate 计算完成，耗时 ${wallClock.elapsedMilliseconds}ms');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _status = '主 isolate 计算失败：$error';
      });
      _addLog('主 isolate 计算失败');
    }
  }

  Future<void> _runWithCompute() async {
    if (_isRunning) return;

    _teardownWorker();
    setState(() {
      _isRunning = true;
      _hasProgress = false;
      _progress = 0;
      _lastStrategy = 'compute()';
      _status = '使用 compute() 把任务放到后台 isolate';
    });
    _addLog('开始 compute() 计算');

    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final wallClock = Stopwatch()..start();
      final result = await compute(_countPrimesPayload, _selectedWorkload);
      wallClock.stop();

      if (!mounted) return;

      final merged = <String, Object>{
        ...result,
        'wallClockMs': wallClock.elapsedMilliseconds,
      };

      setState(() {
        _isRunning = false;
        _progress = 1;
        _lastResult = merged;
        _status = 'UI 仍可响应，说明耗时任务已转移到后台 isolate';
      });
      _addLog('compute() 完成，耗时 ${wallClock.elapsedMilliseconds}ms');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _status = 'compute() 失败：$error';
      });
      _addLog('compute() 失败');
    }
  }

  Future<void> _runWithSpawn() async {
    if (_isRunning) return;

    _teardownWorker();
    setState(() {
      _isRunning = true;
      _hasProgress = true;
      _progress = 0;
      _lastStrategy = 'Isolate.spawn()';
      _status = '启动独立 worker isolate，并通过消息回传进度';
    });
    _addLog('开始 Isolate.spawn() 计算');

    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final wallClock = Stopwatch()..start();
      final receivePort = ReceivePort();
      _receivePort = receivePort;

      _workerSubscription = receivePort.listen((dynamic message) {
        if (!mounted || message is! Map) return;

        final type = message['type'];
        if (type == 'progress') {
          final progress = (message['progress'] as num?)?.toDouble() ?? 0;
          final current = message['current'];
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
            _status = '后台 isolate 处理中，当前检查到 $current';
          });
          return;
        }

        if (type == 'done') {
          wallClock.stop();
          final result = <String, Object>{
            'upperBound': message['upperBound'] as Object,
            'primeCount': message['primeCount'] as Object,
            'checksum': message['checksum'] as Object,
            'elapsedMs': message['elapsedMs'] as Object,
            'wallClockMs': wallClock.elapsedMilliseconds,
          };

          _teardownWorker();

          if (!mounted) return;
          setState(() {
            _isRunning = false;
            _progress = 1;
            _lastResult = result;
            _status = '收到 worker isolate 结果，期间 UI 一直可交互';
          });
          _addLog('Isolate.spawn() 完成，耗时 ${wallClock.elapsedMilliseconds}ms');
        }
      });

      _workerIsolate = await Isolate.spawn<List<Object>>(
        _primeWorker,
        <Object>[receivePort.sendPort, _selectedWorkload],
        debugName: 'prime-worker',
      );
    } catch (error) {
      _teardownWorker();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _hasProgress = false;
        _status = 'Isolate.spawn() 失败：$error';
      });
      _addLog('Isolate.spawn() 失败');
    }
  }

  void _stopWorker() {
    if (!_isRunning) return;
    _teardownWorker();
    setState(() {
      _isRunning = false;
      _hasProgress = false;
      _progress = 0;
      _status = '已手动停止后台 isolate';
    });
    _addLog('手动停止 worker isolate');
  }

  Widget _buildWorkloadChip(int value) {
    final selected = value == _selectedWorkload;
    return ChoiceChip(
      label: Text('上限 $value'),
      selected: selected,
      onSelected: _isRunning
          ? null
          : (_) {
              setState(() {
                _selectedWorkload = value;
              });
            },
    );
  }

  Widget _buildMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _lastResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 线程 / Isolate Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '面试回答核心：Flutter Dart 层的并发单元是 Isolate，不是共享内存线程。'
                  'UI、手势、build 大多运行在主 isolate；一旦主 isolate 被同步计算阻塞，就会掉帧。'
                  'I/O 任务优先 async/await，CPU 密集型任务用 compute() 或 Isolate.spawn() 隔离。',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    RotationTransition(
                      turns: _pulseController,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.sync,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '观察这个旋转球：主 isolate 被阻塞时，它会明显停住',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
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
                    Text('选择计算量', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _workloads.map(_buildWorkloadChip).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '如果设备性能很强，看不出明显卡顿，可以选更大的上限。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _isRunning ? null : () => unawaited(_runOnMainIsolate()),
                  child: const Text('主 isolate 同步计算'),
                ),
                FilledButton.tonal(
                  onPressed: _isRunning ? null : () => unawaited(_runWithCompute()),
                  child: const Text('compute()'),
                ),
                OutlinedButton(
                  onPressed: _isRunning ? null : () => unawaited(_runWithSpawn()),
                  child: const Text('Isolate.spawn()'),
                ),
                TextButton(
                  onPressed: _isRunning ? _stopWorker : null,
                  child: const Text('停止 worker'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前状态', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('策略：$_lastStrategy'),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _isRunning
                          ? (_hasProgress ? _progress : null)
                          : (result == null ? 0 : 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (result != null)
              Row(
                children: [
                  _buildMetric('检查上限', '${result['upperBound']}'),
                  const SizedBox(width: 12),
                  _buildMetric('质数个数', '${result['primeCount']}'),
                ],
              ),
            if (result != null) const SizedBox(height: 12),
            if (result != null)
              Row(
                children: [
                  _buildMetric('计算耗时', '${result['elapsedMs']} ms'),
                  const SizedBox(width: 12),
                  _buildMetric('端到端耗时', '${result['wallClockMs']} ms'),
                ],
              ),
            if (result != null) const SizedBox(height: 12),
            if (result != null)
              Card(
                child: ListTile(
                  title: const Text('校验值 checksum'),
                  subtitle: Text('${result['checksum']}'),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('前后台切换观测', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '这个场景用于说明：前后台切换首先是生命周期变化，不代表 Flutter 会自动切到另一条线程。'
                      '主 isolate 与 worker isolate 是否继续运行，最终还受平台调度与系统挂起策略影响。',
                    ),
                    const SizedBox(height: 12),
                    Text('当前生命周期：$_lifecycleState'),
                    Text('最近切换时间：${_formatDateTime(_lastLifecycleChangedAt)}'),
                    Text('主 isolate 定时器 tick：$_mainIsolateTick'),
                    Text('worker isolate 心跳 tick：$_workerHeartbeatTick'),
                    Text('最近 worker 心跳：$_lastWorkerHeartbeatAt'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: _lifecycleScenarioRunning
                              ? null
                              : () => unawaited(_startLifecycleScenario()),
                          child: const Text('启动前后台场景'),
                        ),
                        OutlinedButton(
                          onPressed: _lifecycleScenarioRunning ? _stopLifecycleScenario : null,
                          child: const Text('停止前后台场景'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '建议演示顺序：\n'
                  '1. 先点“主 isolate 同步计算”，观察旋转球与页面交互停顿。\n'
                  '2. 再点“compute()”，说明一次性 CPU 任务适合直接隔离。\n'
                  '3. 再启动“前后台场景”，按 Home 键或切到其他 App，观察生命周期和 tick 变化。\n'
                  '4. 最后点“Isolate.spawn()”，强调它适合长任务、进度回传和更灵活的消息通信。',
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
                    Text('运行日志', style: theme.textTheme.titleMedium),
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
      ),
    );
  }
}