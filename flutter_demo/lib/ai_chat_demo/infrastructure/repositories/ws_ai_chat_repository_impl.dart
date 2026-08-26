import '../../domain/entities/reply_stream_event.dart';
import '../../domain/entities/session_realtime_event.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../datasources/ws_chat_data_source.dart';

class WsAiChatRepositoryImpl implements AiChatRepository {
  WsAiChatRepositoryImpl(this._dataSource) {
    _dataSource.connect();
  }

  final WsChatDataSource _dataSource;

  @override
  Stream<SessionRealtimeEvent> observeSessionEvents() {
    return _dataSource.sessionEventStream;
  }

  @override
  Future<void> stopReply(String assistantMessageId) {
    return _dataSource.stopCurrentChat();
  }

  @override
  Stream<ReplyStreamEvent> streamReply({
    required String userInput,
    required String assistantMessageId,
  }) {
    return _dataSource.sendChat(
      query: userInput,
      assistantMessageId: assistantMessageId,
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _dataSource.dispose();
  }
}
