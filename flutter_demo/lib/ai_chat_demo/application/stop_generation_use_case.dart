import 'package:flutter/foundation.dart';

import '../domain/repositories/ai_chat_repository.dart';

class StopGenerationUseCase {

  StopGenerationUseCase(this.repository);
  final AiChatRepository repository;

  Future<void> call(String assistantMessageId) async {
    debugPrint('[应用层] StopGenerationUseCase -> 停止生成');
    await repository.stopReply(assistantMessageId);
  }
}
