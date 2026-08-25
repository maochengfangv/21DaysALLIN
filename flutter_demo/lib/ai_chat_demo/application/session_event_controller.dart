import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities/session_realtime_event.dart';
import 'observe_session_events_use_case.dart';

/// 【单一职责】只管WebSocket会话实时事件
/// 依赖UseCase数：1个
/// 代码量：~60行
class SessionEventController extends ChangeNotifier {
  SessionEventController({required this.observeSessionEventsUseCase}) {
    _startListening();
  }

  final ObserveSessionEventsUseCase observeSessionEventsUseCase;

  // ===== 状态：仅会话事件域 =====
  StreamSubscription<SessionRealtimeEvent>? _sessionSubscription;
  final List<SessionRealtimeEvent> _sessionEvents = [];
  bool _isConnected = false;
  int _unreadCount = 0;

  // ===== 节流控制：避免 WS 每秒 8+ 次事件把主线程打爆 =====
  Timer? _notifyThrottleTimer;
  bool _pendingNotify = false;
  static const _throttleDuration = Duration(milliseconds: 100);
  bool _disposed = false;

  // ===== 只读输出 =====
  List<SessionRealtimeEvent> get sessionEvents =>
      List.unmodifiable(_sessionEvents);
  bool get isConnected => _isConnected;
  int get unreadCount => _unreadCount;

  void _startListening() {
    _sessionSubscription = observeSessionEventsUseCase().listen((event) {
      debugPrint('[展示层/SessionEventController] 收到实时事件: ${event.description}');

      switch (event) {
        case ConnectionStateChangedEvent(:final connected):
          _isConnected = connected;
        case UnreadChangedEvent(:final unreadCount):
          _unreadCount = unreadCount;
        case SessionUpdatedEvent():
        case SystemHintEvent():
          break;
      }

      _sessionEvents.add(event);
      if (_sessionEvents.length > 6) _sessionEvents.removeAt(0);
      // ===== 节流：100ms 内最多 1 次 notifyListeners =====
      _throttledNotifyListeners();
    });
  }

  /// 节流版 notifyListeners：合并 100ms 窗口内的高频事件
  void _throttledNotifyListeners() {
    if (_disposed) return;
    // 连接状态变化：立即通知，不节流（影响用户感知）
    if (_notifyThrottleTimer == null) {
      // 第一个窗口内的事件：启动定时器+立即通知一次
      notifyListeners();
      _notifyThrottleTimer = Timer(_throttleDuration, () {
        _notifyThrottleTimer = null;
        // 定时器到时如果有挂起的变更，再补发一次（确保最终一致性）
        if (_pendingNotify && !_disposed) {
          _pendingNotify = false;
          notifyListeners();
        }
      });
    } else {
      // 窗口内的后续事件：只标记，等待定时器到时后合并通知
      _pendingNotify = true;
    }
  }

  void clearUnread() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners(); // 用户主动操作：不节流，立即响应
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyThrottleTimer?.cancel();
    _notifyThrottleTimer = null;
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
