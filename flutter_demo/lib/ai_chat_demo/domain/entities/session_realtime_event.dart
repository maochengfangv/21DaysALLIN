enum SessionRealtimeEventType {
  connectionStateChanged, /// 连接状态改变
  unreadChanged, /// 未读消息改变
  sessionUpdated, /// 会话更新
  systemHint, /// 系统提示
}

class SessionRealtimeEvent {

  final SessionRealtimeEventType type;
  final String description;
  final bool? connected;
  final int? unreadCount;

  const SessionRealtimeEvent._({
    required this.type,
    required this.description,
    this.connected,
    this.unreadCount
  });

  const SessionRealtimeEvent.connectionStateChanged({
    required bool connected,
    required String description,
  }) : this._(type: SessionRealtimeEventType.connectionStateChanged, description: description, connected: connected);
  
  const SessionRealtimeEvent.unreadChanged({
    required int unreadCount,
    required String description,
  }) : this._(type: SessionRealtimeEventType.unreadChanged, description: description, unreadCount: unreadCount);
  
  const SessionRealtimeEvent.sessionUpdated({
    required String description,
  }) : this._(type: SessionRealtimeEventType.sessionUpdated, description: description);
  
  const SessionRealtimeEvent.systemHint({
    required String description,
  }) : this._(type: SessionRealtimeEventType.systemHint, description: description);
}
