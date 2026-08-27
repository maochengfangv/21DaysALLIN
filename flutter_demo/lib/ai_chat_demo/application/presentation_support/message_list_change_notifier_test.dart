import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../ai_chat_controller.dart';

/// 【展示层支持 · Application层】
/// 只在「消息列表相关」维度变化时触发通知：
///   - messages.length（消息数量增删，列表重绘）
///   - replySteps.length（生成状态步骤变更）
///   - generationState.runtimeType（生成状态机迁移：Idle/Preparing/Streaming/...）
///
/// ⚠️ 边界契约：
///   - 不访问 BuildContext / Widget / dart:ui
///   - 可跨多个 Page 复用（如：AiChatMultiWindowPage / AiChatEmbeddedPage）
///   - 可直接在 test/ 目录下 import 写单测
class MessageListChangeNotifier extends ChangeNotifier {
  MessageListChangeNotifier(this._source) {
    _source.addListener(_onChange);
  }

  final AiChatController _source;

  int _lastMessagesLen = -1;
  int _lastStepsLen = -1;
  String _lastGenRuntimeType = '';
  int _lastAssistantContentLen = -1;

  void _onChange() {
    final mLen = _source.messages.length;
    final sLen = _source.replySteps.length;
    final gType = _source.generationState.runtimeType.toString();
    // 🔴 流式输出关键修复：计算所有 assistant 消息的内容总长度
    // 每次 ReplyDelta 追加内容时，此值都会变化，确保打字机效果触发 UI 重建
    final assistantContentLen = _source.messages
        .where((e) => e.role == ChatRole.assistant)
        .fold<int>(0, (sum, e) => sum + e.content.length);
    if (mLen != _lastMessagesLen ||
        sLen != _lastStepsLen ||
        gType != _lastGenRuntimeType ||
        assistantContentLen != _lastAssistantContentLen) {
      _lastMessagesLen = mLen;
      _lastStepsLen = sLen;
      _lastGenRuntimeType = gType;
      _lastAssistantContentLen = assistantContentLen;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onChange);
    super.dispose();
  }
}
