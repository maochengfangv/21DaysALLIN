import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/entities/reply_stream_event.dart';
import '../../domain/entities/session_realtime_event.dart';
import '../dto/ws_frame_dto.dart';
import 'idle_watchdog_manager.dart';

/// ============================================================
/// 【Infrastructure DataSource】WebSocket 对话核心管理器
/// 对应接口文档 §5. WebSocket 实时对话
/// 职责单一：
///   1. 连接生命周期（connect / disconnect / 指数退避重连）
///   2. 25s 心跳 ping / pong 超时检测
///   3. 上行帧发送 + 单 in-flight 互斥锁
///   4. 下行帧解码 → 双路广播（replyStream / sessionEventStream）
///   5. 重连后补发未完成的 pending query（§5.6 要求）
/// 所有时间常量严格对齐接口文档
/// ============================================================
class WsChatDataSource {
  WsChatDataSource({
    required this.host,
    required this.sessionId,
    this.useSsl = false, // 生产强制 true(wss)，Demo 可关
    this.port,
    this.urlPrefix = '/api/v1/ws/chat',
  });

  // ===== 配置 =====
  final String host;
  final int? port;
  final String sessionId;
  final bool useSsl;
  final String urlPrefix;

  // ===== 接口文档常量 =====
  static const _heartbeatInterval = Duration(seconds: 25); // §5.1 25s ping
  static const _idleTimeout = Duration(seconds: 30); // §5.1 30s 无收发=异常
  static const _maxReconnectAttempts = 5; // §5.6 最多 5 次
  static const _initialReconnectDelay =
      Duration(milliseconds: 500); // §5.6 0.5s
  static const _disconnectGracePeriod =
      Duration(milliseconds: 500); // §5.6 主动断留 500ms 给 done

  static const _jitterRangeMs = 400; // 波动范围 +- 200ms
  static const _minBackoffMs = 100; // 最小退避时间 100ms
  static const _maxBackoffMs = 60000; // 最大退避时间 60s

  /// 全局随机数生成器，用于指数退避重连
  static final _reconnectRandom = Random();

  // ===== 内部状态 =====
  WebSocket? _socket;
  Timer? _heartbeatTimer;
  int _lastActivityTs = 0;
  bool _disposed = false;
  bool _userInitiatedDisconnect = false; // 区分主动/被动断
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  final _pendingQueryBucket = <String>[]; // 存未收到 done 的 query（§5.6）
  final _replyStreamController = StreamController<ReplyStreamEvent>.broadcast();
  final _sessionEventController =
      StreamController<SessionRealtimeEvent>.broadcast();
  Completer<void>? _inFlightCompleter; // 单 in-flight 互斥锁（§5.3 chat 帧说明）
  String? _currentAssistantMessageId; // in-flight 期间的消息 ID，Domain 侧生成的
  /// IdleWatchdogManager 注册 key（用自身身份，无需额外字符串）
  Object get _idleWatchdogKey => this;

  // ============================================================
  // 【对外输出】两条独立流，供 Repository 层拉取
  // ============================================================
  Stream<ReplyStreamEvent> get replyStream => _replyStreamController.stream;
  Stream<SessionRealtimeEvent> get sessionEventStream =>
      _sessionEventController.stream;

  // ============================================================
  // 【连接管理】
  // ============================================================
  Future<void> connect() async {
    if (_disposed) return;
    _userInitiatedDisconnect = false;
    try {
      final uri = _buildUri();
      debugPrint('[Infra][WS] 开始连接 $uri');
      final socket = await WebSocket.connect(uri.toString()).timeout(
        const Duration(seconds: 10),
      );
      _socket = socket;
      _reconnectAttempts = 0; // 成功连接即重置计数
      _touchActivity();
      _emitSession(
        const ConnectionStateChangedEvent(
          connected: true,
          description: 'WebSocket 连接成功',
        ),
      );
      debugPrint('[Infra][WS] ✅ 握手成功 (HTTP 101)');

      _startHeartbeat();
      _startIdleWatchdog();
      _listenIncoming();
    } catch (e) {
      debugPrint('[Infra][WS] ❌ 连接失败: $e');
      _emitSession(
        ConnectionStateChangedEvent(
          connected: false,
          description: 'WebSocket 连接失败: $e',
        ),
      );
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // §5.6 主动断开：500ms 延迟给 done 帧留时间
    await Future<void>.delayed(_disconnectGracePeriod);
    await _closeSocket();
  }

  Future<void> _closeSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    IdleWatchdogManager.instance.unregister(_idleWatchdogKey);
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  Uri _buildUri() {
    final scheme = useSsl ? 'wss' : 'ws';
    final path = '$urlPrefix/$sessionId';

    if (port != null) {
      return Uri(scheme: scheme, host: host, port: port, path: path);
    }
    return Uri(scheme: scheme, host: host, path: path);
  }

  // ============================================================
  // 【心跳】§5.1 每 25s 发 ping，服务端回 pong
  // ============================================================
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_socket == null || _disposed) return;
      _sendFrame(WsPingFrame());
    });
  }

  // ============================================================
  // 【空闲看门狗】§5.1 30s 无任何收发 => 链路异常 => 重连
  // P1 优化：接入全局 IdleWatchdogManager（1 个 Timer 扫描 N 个连接）
  // ============================================================
  void _startIdleWatchdog() {
    IdleWatchdogManager.instance.register(
      _idleWatchdogKey,
      // getter：每次扫描时实时拿 _lastActivityTs（闭包捕获 this）
      () => _lastActivityTs,
      // 超时回调：和原独立 Timer 的行为完全一致
      _onIdleTimeout,
      idleThreshold: _idleTimeout,
    );
  }

  /// 空闲超时触发：断开 + 发事件 + 调度重连
  void _onIdleTimeout() {
    if (_disposed || _socket == null) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastActivityTs;
    debugPrint(
      '[Infra][WS] ⚠️ 空闲超时 ${elapsed}ms>30s，判定链路异常，断开并重连',
    );
    unawaited(_closeSocket());
    _emitSession(
      const ConnectionStateChangedEvent(
        connected: false,
        description: 'WebSocket 30s 空闲超时，触发重连',
      ),
    );
    _scheduleReconnect();
  }

  void _touchActivity() {
    _lastActivityTs = DateTime.now().millisecondsSinceEpoch;
  }

  // ============================================================
  // 【下行帧监听】解码 → 分发到两个 Stream
  // ============================================================
  void _listenIncoming() {
    final socket = _socket;
    if (socket == null) return;
    socket.listen(
      (dynamic raw) {
        _touchActivity();
        if (raw is! String) {
          debugPrint('[Infra][WS] 收到非文本帧，忽略');
          return;
        }
        final frame = WsIncomingFrame.decode(raw);
        _dispatchIncoming(frame);
      },
      onError: (Object e) {
        debugPrint('[Infra][WS] onError: $e');
        _emitSession(
          ConnectionStateChangedEvent(
            connected: false,
            description: 'WebSocket 出错: $e',
          ),
        );
        _finishInFlightWithError(e.toString());
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[Infra][WS] onDone：连接已关闭');
        _emitSession(
          const ConnectionStateChangedEvent(
            connected: false,
            description: 'WebSocket 连接已断开',
          ),
        );
        _finishInFlightWithError('连接已断开');
        _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _dispatchIncoming(WsIncomingFrame frame) {
    switch (frame) {
      case WsPongFrame():
        debugPrint('[Infra][WS] ← pong');
      // pong 静默消费即可，心跳的 _lastActivityTs 已在 listen 回调里更新
      case WsStartFrame():
        debugPrint('[Infra][WS] ← start');
        final msgId = _currentAssistantMessageId;
        if (msgId != null) {
          _pendingQueryBucket.clear(); // 开始新一轮时清空旧 pending
          _replyStreamController.add(ReplyStarted(messageId: msgId));
        } else {
          debugPrint(
            '[Infra][WS] ⚠️ 收到 start 帧但 _currentAssistantMessageId 为空，'
            '已静默丢弃（可能原因：重连后多端广播 / 非本端发起的 chat，'
            '后续多端同步能力完成后需改为按 session 路由）',
          );
        }
      case WsChunkFrame(data: final text):
        final msgId = _currentAssistantMessageId;
        if (msgId != null) {
          _replyStreamController.add(ReplyDelta(messageId: msgId, text: text));
        } else {
          debugPrint(
            '[Infra][WS] ⚠️ 收到 chunk 帧(${text.length} chars)但 _currentAssistantMessageId 为空，已静默丢弃',
          );
        }
      case WsDoneFrame():
        debugPrint('[Infra][WS] ← done');
        final msgId = _currentAssistantMessageId;
        if (msgId != null) {
          _replyStreamController.add(ReplyFinished(messageId: msgId));
        } else {
          debugPrint(
            '[Infra][WS] ⚠️ 收到 done 帧但 _currentAssistantMessageId 为空',
          );
        }
        _finishInFlight(); // done 帧无论如何都必须释放 in-flight 锁，避免死锁
      case WsErrorFrame(data: final errMsg):
        debugPrint('[Infra][WS] ← error: $errMsg');
        final msgId = _currentAssistantMessageId;
        if (msgId != null) {
          _replyStreamController
              .add(ReplyFailed(messageId: msgId, error: errMsg));
        }
        _finishInFlightWithError(errMsg);
        // §5.4：错误帧发完后服务端主动关闭，我们也主动关避免半开
        unawaited(_closeSocket());
        _scheduleReconnect();
      case WsUnknownFrame():
        debugPrint('[Infra][WS] ⚠️ 未知帧 type=${frame.type}，忽略（预留后续扩展）');
        _emitSession(
          SystemHintEvent(
            description: '收到未定义 WS 帧 type=${frame.type}',
          ),
        );
      case WsMalformedFrame():
        debugPrint('[Infra][WS] ❌ 坏帧 error=${frame.error}，raw=${frame.raw}');
    }
  }

  // ============================================================
  // 【上行】发送 chat 帧，返回该次 chat 的专属流（给 Repository 用）
  // 单 in-flight 互斥：§5.3 明确"同一时刻只允许 1 个 in-flight 请求"
  // ============================================================
  Stream<ReplyStreamEvent> sendChat({
    required String query,
    required String assistantMessageId,
  }) {
    if (_disposed) {
      return Stream.error(StateError('WsChatDataSource 已 dispose'));
    }

    final controller = StreamController<ReplyStreamEvent>();
    // 订阅全局 replyStream，只取 messageId 匹配的事件 → 返回给 Repository 的专属流
    StreamSubscription<ReplyStreamEvent>? sub;
    sub = replyStream.listen(
      (event) {
        if (event.messageId != assistantMessageId) return;
        controller.add(event);
        if (event is ReplyFinished ||
            event is ReplyFailed ||
            event is ReplyCanceled) {
          sub?.cancel();
          controller.close();
        }
      },
      onError: (Object e) {
        controller.addError(e);
        controller.close();
      },
    );

    // 立即启动发送流程（异步，不阻塞 Stream 构建）
    _enqueueChatRequest(query: query, assistantMessageId: assistantMessageId)
        .catchError((Object e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 停止当前 in-flight 请求（Domain 层 stopReply）
  /// WS 协议文档 §5 没有定义 stop/cancel 上行帧，实现为：
  ///   本地合成一条 ReplyCanceled，让 UI 立刻结束打字态 + 解锁 in-flight 互斥
  /// 若后端后续新增 {"type":"cancel"} 上行帧协议，在此处补 _sendFrame 即可
  Future<void> stopCurrentChat() async {
    final msgId = _currentAssistantMessageId;
    if (msgId != null) {
      _replyStreamController.add(
        ReplyCanceled(
          messageId: msgId,
          reason: '用户停止生成',
        ),
      );
    } else {
      debugPrint('[Infra][WS] stopCurrentChat 被调用，但无 in-flight 消息，忽略');
    }
    _finishInFlight();
  }

  Future<void> _enqueueChatRequest({
    required String query,
    required String assistantMessageId,
  }) async {
    // 单 in-flight 互斥：前一个没 done 就等
    if (_inFlightCompleter != null) {
      await _inFlightCompleter!.future;
      if (_disposed) return;
    }
    _inFlightCompleter = Completer<void>();
    _currentAssistantMessageId = assistantMessageId;
    _pendingQueryBucket
      ..clear()
      ..add(query); // §5.6 存入 pending，重连后补发
    _sendFrame(WsChatFrame(query: query));
  }

  void _finishInFlight() {
    _currentAssistantMessageId = null;
    _pendingQueryBucket.clear();
    final c = _inFlightCompleter;
    _inFlightCompleter = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _finishInFlightWithError(String error) {
    // 错误不自动 retry，让上层决定（避免重复触发）
    _currentAssistantMessageId = null;
    _pendingQueryBucket.clear();
    final c = _inFlightCompleter;
    _inFlightCompleter = null;
    if (c != null && !c.isCompleted) c.completeError(error);
  }

  void _sendFrame(WsOutgoingFrame frame) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      debugPrint('[Infra][WS] 发送失败：socket 未就绪，type=${frame.toJson()['type']}');
      return;
    }
    try {
      socket.add(frame.encode());
      _touchActivity();
      debugPrint('[Infra][WS] → 已发送 ${frame.toJson()['type']}');
    } catch (e) {
      debugPrint('[Infra][WS] 发送异常 $e');
    }
  }

  // ============================================================
  // 【重连】§5.6：0.5s→1s→2s→4s→8s 指数退避，最多 5 次
  // ============================================================
  void _scheduleReconnect() {
    if (_disposed || _userInitiatedDisconnect) return;
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[Infra][WS] 已达最大重连次数 $_maxReconnectAttempts，停止重连');
      _emitSession(
        const ConnectionStateChangedEvent(
          connected: false,
          description: '重连次数用尽，请检查网络',
        ),
      );
      return;
    }
    final backoffMs = _initialReconnectDelay.inMilliseconds *
        (1 << _reconnectAttempts); // 位运算实现 2^n

    final baseBackoffMs =
        _initialReconnectDelay.inMilliseconds * (1 << _reconnectAttempts);
    final jitterMs = _reconnectRandom.nextInt(_jitterRangeMs);
    final finalBackoffMs = baseBackoffMs + jitterMs;
    finalBackoffMs.clamp(_minBackoffMs, _maxBackoffMs);

    _reconnectAttempts++;
    debugPrint(
      '[Infra][WS] 第 $_reconnectAttempts 次重连，'
      'base=${baseBackoffMs}ms jitter=${jitterMs >= 0 ? '+' : ''}$jitterMs ms '
      '→ 实际延迟 ${backoffMs}ms',
    );
    _reconnectTimer = Timer(Duration(milliseconds: backoffMs), () async {
      await connect();
      // 重连成功后补发 pending query（§5.6 要求）
      if (_pendingQueryBucket.isNotEmpty && _socket != null) {
        final query = _pendingQueryBucket.last;
        final msgId = _currentAssistantMessageId;
        if (msgId != null) {
          debugPrint('[Infra][WS] 🔁 重连后补发 pending query');
          _sendFrame(WsChatFrame(query: query));
        }
      }
    });
  }

  // ============================================================
  // 【生命周期】
  // ============================================================
  void _emitSession(SessionRealtimeEvent e) => _sessionEventController.add(e);

  Future<void> dispose() async {
    _disposed = true;
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    await _replyStreamController.close();
    await _sessionEventController.close();
    await disconnect();
  }
}
