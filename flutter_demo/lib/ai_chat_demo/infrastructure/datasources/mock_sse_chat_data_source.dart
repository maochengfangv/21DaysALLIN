import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/message_content_format.dart';
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
      yield ReplyStarted(
        messageId: assistantMessageId,
        contentFormat: MessageContentFormat.markdown,
      );
      
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
    return '# AI 回答示例\n\n'
        '你刚刚输入的是：**$userInput**。\n\n'
        '这是一次通过 SSE 返回的 Markdown 富文本示例：\n\n'
        '- 支持列表\n'
        '- 支持 **加粗** 与 *斜体*\n'
        '- 支持 [Flutter 官网](https://flutter.dev) 链接\n\n'
        '![示例图片](https://picsum.photos/320/180)\n\n'
        '> WebSocket 继续负责会话状态、未读数、连接状态等实时事件。\n\n'
        '```dart\n'
        'debugPrint("SSE streaming markdown demo");\n'
        '```';
  }

  List<String> _splitAnswer(String text) {
    const chunkSize = 24;
    final result = <String>[];
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      result.add(text.substring(i, end));
    }
    return result;
  }
}