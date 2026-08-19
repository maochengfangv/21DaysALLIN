import 'package:flutter/foundation.dart';
import '../domain/entities/reply_stream_event.dart';
import '../domain/repositories/ai_chat_repository.dart';

class SendChatMessageUseCase {
  final AiChatRepository repository;

  SendChatMessageUseCase(this.repository);

 Stream<ReplyStreamEvent> call({
    required String userInput,
    required String assistantMessageId,
  }) {
    debugPrint('[应用层] SendChatMessageUseCase -> 发起流式回复');
    return repository.streamReply(
      userInput: userInput,
      assistantMessageId: assistantMessageId,
    );
  }
}