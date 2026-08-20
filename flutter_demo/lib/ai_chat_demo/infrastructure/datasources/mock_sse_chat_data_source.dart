import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/reply_stream_event.dart';

class MockSseChatDataSource {
  final Map<String, bool> _stopFlags = <String, bool>{};

  Stream<ReplyStreamEvent> streamReply({
    required String userInput,
    required String assistantMessageId,
  }) async* {
     debugPrint('[基础设施层][SSE] 建立回答流 assistantMessageId=$assistantMessageId');
    _stopFlags[assistantMessageId] = false;
    try {
      yield ReplyStarted(messageId: assistantMessageId);
      
      const steps = <String> [
        '正在检索知识库',
        '正在分析上下文',
        '正在生成最终回答',
      ];

      for (final step in steps) {

        if (_shouldStop(assistantMessageId)) {
          yield ReplyCanceled(
            messageId: assistantMessageId,
            reason: '用户已停止生成',
          );
          return;
        }

        await Future.delayed(const Duration(milliseconds: 650));
        yield ReplyStatus(messageId: assistantMessageId, text: step);
      }

      final chunks = _splitAnswer(_buildMockAnswer(userInput));
      for (final chunk in chunks) {
        if(_shouldStop(assistantMessageId)) {
          yield ReplyCanceled(
            messageId: assistantMessageId,
            reason: '用户已停止生成',
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 220));
        yield ReplyDelta(messageId: assistantMessageId, text: chunk);
      }

      yield ReplyFinished(messageId: assistantMessageId); 
    } catch (error) {
      yield ReplyFailed(messageId: assistantMessageId, error: error.toString());
    } finally {
      _stopFlags.remove(assistantMessageId);
    }
  }

    Future<void> stopReply(String assistantMessageId) async {
    debugPrint('[基础设施层][SSE] 标记停止 assistantMessageId=$assistantMessageId');
    _stopFlags[assistantMessageId] = true;
  }
  bool _shouldStop(String assistantMessageId) {
     return _stopFlags[assistantMessageId] ?? false;
  }

    String _buildMockAnswer(String userInput) {
    return '你刚刚输入的是“$userInput”。'
        '在这个 Demo 里，SSE 负责持续把大模型 token 一段段推给前端，'
        '所以你会看到类似打字机的流式回复效果。'
        '与此同时，WebSocket 不负责正文输出，而是负责会话状态、未读数、连接状态等实时事件。'
        '这就是 AI 聊天 App 中“回答流”和“事件流”拆分的典型落地方式。';
  }

  List<String> _splitAnswer(String text) {
    const chunkSize = 12;
    final result = <String>[];
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      result.add(text.substring(i, end));
    }
    return result;
  }
}