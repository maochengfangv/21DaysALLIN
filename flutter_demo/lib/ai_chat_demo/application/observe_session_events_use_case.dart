import 'package:flutter/foundation.dart';

import '../domain/entities/session_realtime_event.dart';
import '../domain/repositories/ai_chat_repository.dart';

class ObserveSessionEventsUseCase {
  final AiChatRepository repository;

  ObserveSessionEventsUseCase(this.repository);

  Stream<SessionRealtimeEvent> call() {
    debugPrint('[应用层] ObserveSessionEventsUseCase -> 订阅会话实时事件');
    return repository.observeSessionEvents();
  }
}