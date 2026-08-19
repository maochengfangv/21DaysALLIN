import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_demo/ai_chat_demo/application/observe_session_events_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/send_chat_message_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/stop_generation_use_case.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/reply_stream_event.dart';
import '../domain/entities/session_realtime_event.dart';


class AiChatController extends ChangeNotifier {
  final SendChatMessageUseCase sendChatMessageUseCase;
  final StopGenerationUseCase stopGenerationUseCase;
  final ObserveSessionEventsUseCase observeSessionEventsUseCase;
  final VoidCallback disposeRepository;

  AiChatController({
    required this.sendChatMessageUseCase,
    required this.stopGenerationUseCase,
    required this.observeSessionEventsUseCase,
    required this.disposeRepository,
  }) {
        _listenSessionEvents();
        _messages.add(ChatMessage(id: 'welcome', role: ChatRole.system, content: '这是一个离线可运行 Demo：SSE 负责回答流，WebSocket 负责实时事件流',createdAt: DateTime.now()));
      }
  final List<ChatMessage> _messages = [];
  final List<String> _replySteps = [];
  final List<SessionRealtimeEvent> _sessionEvents = [];

  StreamSubscription<ReplyStreamEvent>? _replySubscription;
  StreamSubscription<SessionRealtimeEvent>? _sessionSubscription;

  bool _isGenerating = false;
  bool _isConnected = false;
  int _unreadCount = 0;
  String? _currentAssistantMessageId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get replySteps => List.unmodifiable(_replySteps);
  List<SessionRealtimeEvent> get sessionEvents => List.unmodifiable(_sessionEvents);

  bool get isGenerating => _isGenerating;
  bool get isConnected => _isConnected;
  int get unreadCount => _unreadCount;

  void _listenSessionEvents() {
    _sessionSubscription = observeSessionEventsUseCase().listen((event) {
      debugPrint('[展示层/Controller] 收到实时事件: ${event.description}');

      if (event.type == SessionRealtimeEventType.connectionStateChanged) {
        _isConnected = event.connected ?? false;
      }

      if (event.type == SessionRealtimeEventType.unreadChanged) {
        _unreadCount = event.unreadCount ?? _unreadCount;
      }

      _sessionEvents.add(event);
      if(_sessionEvents.length > 6) {
        _messages.removeAt(0);
      }
      notifyListeners();
    });
  }

  Future<void> sendMessage(String input) async {
   final text = input.trim();
   if(text.isEmpty) {
     return;
   }

   final userMessage = ChatMessage(id: 'user_${DateTime.now().microsecondsSinceEpoch}', role: ChatRole.user, content: text, createdAt: DateTime.now());

   final asssistantMessageId = 'assistant_${DateTime.now().microsecondsSinceEpoch}';

  final assistantPlaceholder = ChatMessage(id: asssistantMessageId, role: ChatRole.assistant, content: '', createdAt: DateTime.now());

  _messages.add(userMessage);
  _messages.add(assistantPlaceholder);
  _replySteps.clear();
  _isGenerating = true;
  _currentAssistantMessageId = asssistantMessageId;
  notifyListeners();
  await _replySubscription?.cancel();
  _replySubscription = sendChatMessageUseCase(userInput:text, assistantMessageId: asssistantMessageId).listen(_handleReplyEvent);
}

  void _handleReplyEvent(ReplyStreamEvent event) {
     debugPrint('[展示层/Controller] 收到回复流事件: ${event.type}');
     switch (event.type){
       case ReplyStreamEventType.started:
        _appendReplyStep('SSE 已建立连接，开始接收模型输出');
         break;
       case ReplyStreamEventType.status:
        _appendReplyStep(event.text ?? '');
         break;
        case ReplyStreamEventType.delta:
        _appendDelta(event.messageId, event.text ?? '');
         break;
       case ReplyStreamEventType.finished:
       _appendReplyStep('本次回答已完成');
        _isGenerating = false;
        _currentAssistantMessageId = null;
         break;
        case ReplyStreamEventType.failed:
       _appendReplyStep('生成失败: ${event.error}');
        _isGenerating = false;
        _currentAssistantMessageId = null;
         break;
     }
      notifyListeners();
  }

  void _appendReplyStep(String step) {
    if(step.isEmpty) {
      return;
    }
    _replySteps.add(step);
    if (_replySteps.length > 8) {
      _replySteps.removeAt(0);
    }
  }

  void _appendDelta(String messageId, String delta) {
    final index = _messages.indexWhere((element) => element.id == messageId);
    if(index == -1) {
      return;
    }
    final current = _messages[index];
    _messages[index] = current.copyWith(content: current.content + delta);
  }

  Future<void> stopGenerating() async {
    if(!_isGenerating || _currentAssistantMessageId == null) {
      return;
    }
    await stopGenerationUseCase(_currentAssistantMessageId!);
  }

  void dispose() {
    _replySubscription?.cancel();
    _sessionSubscription?.cancel();
    disposeRepository();
    super.dispose();
  }
}

