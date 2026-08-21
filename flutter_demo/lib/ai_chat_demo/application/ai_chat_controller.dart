import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_demo/ai_chat_demo/application/observe_session_events_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/send_chat_message_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/stop_generation_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/pick_image_from_gallery_use_case.dart';
import 'chat_generation_state.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/message_content_format.dart';
import '../domain/entities/reply_stream_event.dart';
import '../domain/entities/session_realtime_event.dart';

class AiChatController extends ChangeNotifier {
  final SendChatMessageUseCase sendChatMessageUseCase;
  final StopGenerationUseCase stopGenerationUseCase;
  final ObserveSessionEventsUseCase observeSessionEventsUseCase;
  final PickImageFromGalleryUseCase pickImageFromGalleryUseCase;
  final VoidCallback disposeRepository;

  AiChatController({
    required this.sendChatMessageUseCase,
    required this.stopGenerationUseCase,
    required this.observeSessionEventsUseCase,
    required this.pickImageFromGalleryUseCase,
    required this.disposeRepository,
  }) {
    _listenSessionEvents();
    _messages.add(ChatMessage(
        id: 'welcome',
        role: ChatRole.system,
        content: '这是一个离线可运行 Demo：SSE 负责回答流，WebSocket 负责实时事件流',
        createdAt: DateTime.now()));
  }
  final List<ChatMessage> _messages = [];
  final List<String> _replySteps = [];
  final List<SessionRealtimeEvent> _sessionEvents = [];

  StreamSubscription<ReplyStreamEvent>? _replySubscription;
  StreamSubscription<SessionRealtimeEvent>? _sessionSubscription;

  ChatGenerationState _generationState = const IdleState();
  bool _isConnected = false;
  int _unreadCount = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get replySteps => List.unmodifiable(_replySteps);
  List<SessionRealtimeEvent> get sessionEvents =>
      List.unmodifiable(_sessionEvents);

  ChatGenerationState get generationState => _generationState;
  bool get isGenerating => _generationState.isInFlight;
  bool get canSend => _generationState.canSend;
  bool get canStop => _generationState.canStop;
  String get generationLabel => _generationState.label;

  bool get isConnected => _isConnected;
  int get unreadCount => _unreadCount;

  String? get currentAssistantMessageId => _generationState.assistantMessageId;

  void _listenSessionEvents() {
    _sessionSubscription = observeSessionEventsUseCase().listen((event) {
      debugPrint('[展示层/Controller] 收到实时事件: ${event.description}');

      switch (event) {
        case ConnectionStateChangedEvent(:final connected):
          _isConnected = connected;
        case UnreadChangedEvent(:final unreadCount):
          _unreadCount = unreadCount;
        case SessionUpdatedEvent():
        case SystemHintEvent():
          break;
      }

      _sessionEvents.add(event);
      if (_sessionEvents.length > 6) {
        _sessionEvents.removeAt(0);
      }
      notifyListeners();
    });
  }

  Future<void> sendMessage(String input) async {
    if (!canSend) {
      return;
    }

    final text = input.trim();
    if (text.isEmpty) {
      return;
    }

    final userMessage = ChatMessage(
        id: 'user_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        content: text,
        createdAt: DateTime.now());

    final asssistantMessageId =
        'assistant_${DateTime.now().microsecondsSinceEpoch}';

    final assistantPlaceholder = ChatMessage(
      id: asssistantMessageId,
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
        assistantMessageId: asssistantMessageId,
        step: '已提交问题，等待建立 SSE 连接',
      ),
    );

    notifyListeners();
    await _replySubscription?.cancel();
    _replySubscription = sendChatMessageUseCase(
            userInput: text, assistantMessageId: asssistantMessageId)
        .listen(_handleReplyEvent);
  }

  void _handleReplyEvent(ReplyStreamEvent event) {
    debugPrint('[展示层/Controller] 收到回复流事件: ${event.runtimeType}');

    switch (event) {
      case ReplyStarted(:final messageId, :final contentFormat):
        const step = 'SSE 已建立连接，开始接收模型输出';
        _appendReplyStep(step);
        _updateMessageContentFormat(messageId, contentFormat);
        _updateMessageStatus(messageId, ChatMessageStatus.streaming);
        _transitionTo(
            PreparingState(assistantMessageId: messageId, step: step));
      case ReplyStatus(:final messageId, :final text):
        _appendReplyStep(text);
        _updateMessageStatus(messageId, ChatMessageStatus.streaming);
        _transitionTo(
            PreparingState(assistantMessageId: messageId, step: text));
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
        _updateMessageStatus(messageId, ChatMessageStatus.canceled,
            errorMessage: reason);
        _transitionTo(
          CanceledState(assistantMessageId: messageId, reason: reason),
        );
      case ReplyFailed(:final messageId, :final error):
        _appendReplyStep('生成失败: $error');
        _updateMessageStatus(messageId, ChatMessageStatus.failed,
            errorMessage: error);
        _transitionTo(FailedState(assistantMessageId: messageId, error: error));
    }

    notifyListeners();
  }

  void _appendReplyStep(String step) {
    if (step.isEmpty) {
      return;
    }
    _replySteps.add(step);
    if (_replySteps.length > 8) {
      _replySteps.removeAt(0);
    }
  }

  void _appendDelta(String messageId, String delta) {
    final index = _messages.indexWhere((element) => element.id == messageId);
    if (index == -1) {
      return;
    }
    final current = _messages[index];
    _messages[index] = current.copyWith(content: current.content + delta);
  }

  Future<void> stopGenerating() async {
    final assistantMessageId = currentAssistantMessageId;
    if (!canStop || assistantMessageId == null) {
      return;
    }
    _transitionTo(StoppingState(assistantMessageId: assistantMessageId));
    notifyListeners();
    await stopGenerationUseCase(assistantMessageId);
  }

  Future<void> pickImageFromGallery() async {
   final imagePath =  await pickImageFromGalleryUseCase();
   if (imagePath == null) {
    return;
   }
  //  _messages.add(ChatMessage(id: 'system_image_${DateTime.now().microsecondsSinceEpoch}', role: ChatRole.system, content: '已选择图片：$imagePath', createdAt: DateTime.now()));
  //  notifyListeners();
  }

  @override
  void dispose() {
    _replySubscription?.cancel();
    _sessionSubscription?.cancel();
    disposeRepository();
    super.dispose();
  }

  int _messageLength(String messageId) {
    final index = _messages.indexWhere((element) => element.id == messageId);
    if (index == -1) {
      return 0;
    }
    return _messages[index].content.length;
  }

  void _updateMessageStatus(
    String messageId,
    ChatMessageStatus status, {
    String? errorMessage,
  }) {
    final index = _messages.indexWhere((element) => element.id == messageId);
    if (index == -1) {
      return;
    }
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
    final index = _messages.indexWhere((element) => element.id == messageId);
    if (index == -1) {
      return;
    }
    final current = _messages[index];
    _messages[index] = current.copyWith(contentFormat: contentFormat);
  }

  void _transitionTo(ChatGenerationState nextState) {
    _generationState = nextState;
  }
}
