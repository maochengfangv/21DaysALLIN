import '../../domain/entities/reply_stream_event.dart';
import '../../domain/entities/session_realtime_event.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../datasources/mock_sse_chat_data_source.dart';
import '../datasources/mock_websocket_event_data_source.dart';

class MockAiChatRepositoryImpl implements AiChatRepository {

  final MockSseChatDataSource sseChatDataSource;
  final MockWebSocketEventDataSource websocketEventDataSource;

  const MockAiChatRepositoryImpl({
    required this.sseChatDataSource,
    required this.websocketEventDataSource,
  });

  @override
  void dispose() {
  }

  @override
  Stream<SessionRealtimeEvent> observeSessionEvents() {
   return websocketEventDataSource.observeEvents();
  }

  @override
  Future<void> stopReply(String assistantMessageId) {
   return sseChatDataSource.stopReply(assistantMessageId);
  }

  @override
  Stream<ReplyStreamEvent> streamReply({required String userInput, required String assistantMessageId}) {
   return sseChatDataSource.streamReply(userInput: userInput, assistantMessageId: assistantMessageId);
  }

  
}