import '../../domain/entities/session_realtime_event.dart';

class MockWebSocketEventDataSource {
  Stream<SessionRealtimeEvent> observeEvents() async* {
    yield const SessionRealtimeEvent.connectionStateChanged(
      connected: true,
      description: 'WebSocket 已连接',
    );

    yield const SessionRealtimeEvent.systemHint(
      description: '实时事件流已启动：后续会推送未读数和会话状态',
    );

    var unreadCount = 0;
    var round = 0;

    while (true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      unreadCount = (unreadCount + 1) % 4;
      yield SessionRealtimeEvent.unreadChanged(
        unreadCount: unreadCount,
        description: '未读消息数更新为 $unreadCount',
      );

      await Future<void>.delayed(const Duration(seconds: 2));
      round++;
      yield SessionRealtimeEvent.sessionUpdated(
        description: '会话列表已同步，第 $round 次增量更新',
      );
    }
  }
}