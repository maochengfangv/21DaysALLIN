sealed class SessionRealtimeEvent {
  const SessionRealtimeEvent({required this.description});

  final String description;
}

final class ConnectionStateChangedEvent extends SessionRealtimeEvent {
  const ConnectionStateChangedEvent({
    required super.description,
    required this.connected,
  });

  final bool connected;
}

final class UnreadChangedEvent extends SessionRealtimeEvent {
  const UnreadChangedEvent({
    required super.description,
    required this.unreadCount,
  });

  final int unreadCount;
}

final class SessionUpdatedEvent extends SessionRealtimeEvent {
  const SessionUpdatedEvent({required super.description});
}

final class SystemHintEvent extends SessionRealtimeEvent {
  const SystemHintEvent({required super.description});
}
