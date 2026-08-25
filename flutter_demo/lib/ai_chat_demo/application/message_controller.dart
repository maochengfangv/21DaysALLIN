import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/message_content_format.dart';
import '../domain/entities/reply_stream_event.dart';
import 'chat_generation_state.dart';
import 'send_chat_message_use_case.dart';
import 'stop_generation_use_case.dart';

/// 【单一职责】只管消息列表与生成状态机
class MessageController extends ChangeNotifier {
  MessageController({
    required this.sendChatMessageUseCase,
    required this.stopGenerationUseCase,
  }) {
    _appendWelcomeMessage();
  }
  final SendChatMessageUseCase sendChatMessageUseCase;
  final StopGenerationUseCase stopGenerationUseCase;

  // === 状态：仅消息域 ===

  final List<ChatMessage> _messages = [];
  final List<String> _replySteps = [];

  ChatGenerationState _generationState = const IdleState();
  StreamSubscription<ReplyStreamEvent>? _replySubscription;
  String _prefilledInput = '';

  // === 只读输出 ====
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get replySteps => List.unmodifiable(_replySteps);
  ChatGenerationState get generationState => _generationState;
  bool get isGenerating => _generationState.isInFlight;
  bool get canSend => _generationState.canSend;
  bool get canStop => _generationState.canStop;
  String get generationLabel => _generationState.label;
  String? get currentAssistantMessageId => _generationState.assistantMessageId;
  String get prefilledInput => _prefilledInput;

  /// 供Coordinator使用：语音/其他输入方式填入待发送文本
  void prefillInput(String text) {
    _prefilledInput = text;
    notifyListeners();
  }

  /// 供Coordinator使用：发送消息
  /// [attachments] 参数预留，后续多模态接入时启用
  Future<void> sendMessage(String input, {List<Object>? attachments}) async {
    // ignore: avoid_bool_literals_in_conditional_expressions
    if (!canSend) return;

    final text = input.trim();
    if (text.isEmpty) return;

    _prefilledInput = '';

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      content: text,
      createdAt: DateTime.now(),
    );

    final assistantMessageId =
        'assistant_${DateTime.now().microsecondsSinceEpoch}';

    final assistantPlaceholder = ChatMessage(
      id: assistantMessageId,
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: ChatMessageStatus.pending,
    );
    _messages.add(userMessage);
    _messages.add(assistantPlaceholder);
    _replySteps.clear();

    _appendReplyStep('已提交问题，等待建立 SSE 连接');
    _transitionTo(
      PreparingState(
        assistantMessageId: assistantMessageId,
        step: '已提交问题，等待建立 SSE 连接',
      ),
    );
    notifyListeners();
    await _replySubscription?.cancel();
    _replySubscription = sendChatMessageUseCase(
      userInput: text,
      assistantMessageId: assistantMessageId,
    ).listen(_handleReplyEvent);
  }

  /// 供Coordinator使用：停止生成
  Future<void> stopGenerating() async {
    final assistantMessageId = currentAssistantMessageId;
    if (!canStop || assistantMessageId == null) return;
    _transitionTo(StoppingState(assistantMessageId: assistantMessageId));
    notifyListeners();
    await stopGenerationUseCase(assistantMessageId);
  }

  void _appendWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome',
        role: ChatRole.system,
        content: '这是一个离线可运行 Demo：SSE 负责回答流，WebSocket 负责实时事件流',
        createdAt: DateTime.now(),
      ),
    );
  }

  void _handleReplyEvent(ReplyStreamEvent event) {
    debugPrint('[展示层/MessageController] 收到回复流事件: ${event.runtimeType}');

    switch (event) {
      case ReplyStarted(:final messageId, :final contentFormat):
        const step = 'SSE 已建立连接，开始接收模型输出';
        _appendReplyStep(step);
        _updateMessageContentFormat(messageId, contentFormat);
        _updateMessageStatus(messageId, ChatMessageStatus.streaming);
        _transitionTo(
          PreparingState(assistantMessageId: messageId, step: step),
        );
      case ReplyStatus(:final messageId, :final text):
        _appendReplyStep(text);
        _updateMessageStatus(messageId, ChatMessageStatus.streaming);
        _transitionTo(
          PreparingState(assistantMessageId: messageId, step: text),
        );
      case ReplyDelta(:final messageId, :final text):
        _appendDelta(messageId, text);
        _updateMessageStatus(messageId, ChatMessageStatus.streaming);
        _transitionTo(
          StreamingState(
            assistantMessageId: messageId,
            receivedChars: _messageLength(messageId),
          ),
        );
      case ReplyFinished(:final messageId):
        _appendReplyStep('本次回答已完成');
        _updateMessageStatus(messageId, ChatMessageStatus.completed);
        _transitionTo(CompletedState(assistantMessageId: messageId));
      case ReplyCanceled(:final messageId, :final reason):
        _appendReplyStep(reason);
        _updateMessageStatus(
          messageId,
          ChatMessageStatus.canceled,
          errorMessage: reason,
        );
        _transitionTo(
          CanceledState(assistantMessageId: messageId, reason: reason),
        );
      case ReplyFailed(:final messageId, :final error):
        _appendReplyStep('生成失败: $error');
        _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          errorMessage: error,
        );
        _transitionTo(FailedState(assistantMessageId: messageId, error: error));
    }

    notifyListeners();
  }

  void _updateMessageStatus(
    String messageId,
    ChatMessageStatus status, {
    String? errorMessage,
  }) {
    final index = _messages.indexWhere((e) => e.id == messageId);
    if (index == -1) return;
    final current = _messages[index];
    _messages[index] = current.copyWith(
      status: status,
      errorMessage: errorMessage ?? current.errorMessage,
    );
  }

  void _updateMessageContentFormat(
    String messageId,
    MessageContentFormat contentFormat,
  ) {
    final index = _messages.indexWhere((e) => e.id == messageId);
    if (index == -1) return;
    final current = _messages[index];
    _messages[index] = current.copyWith(contentFormat: contentFormat);
  }

  void _appendReplyStep(String step) {
    if (step.isEmpty) return;
    _replySteps.add(step);
    if (_replySteps.length > 8) _replySteps.removeAt(0);
  }

  void _appendDelta(String messageId, String delta) {
    final index = _messages.indexWhere((e) => e.id == messageId);
    if (index == -1) return;
    final current = _messages[index];
    _messages[index] = current.copyWith(content: current.content + delta);
  }

  int _messageLength(String messageId) {
    final index = _messages.indexWhere((e) => e.id == messageId);
    return index == -1 ? 0 : _messages[index].content.length;
  }

  void _transitionTo(ChatGenerationState nextState) {
    _generationState = nextState;
  }

  @override
  void dispose() {
    _replySubscription?.cancel();
    super.dispose();
  }
}
