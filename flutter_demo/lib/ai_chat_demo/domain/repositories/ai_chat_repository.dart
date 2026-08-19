import '../entities/reply_stream_event.dart';
import '../entities/session_realtime_event.dart';
/// 领域层抽象 AI聊天
abstract class AiChatRepository {
  Stream<ReplyStreamEvent> streamReply({
    required String userInput,
    required String assistantMessageId
  });

Future<void> stopReply(String assistantMessageId);

Stream<SessionRealtimeEvent> observeSessionEvents();

void dispose();

}