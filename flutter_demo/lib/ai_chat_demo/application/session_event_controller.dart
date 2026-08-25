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
      notifyListeners();
    });
  }

  void clearUnread() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
