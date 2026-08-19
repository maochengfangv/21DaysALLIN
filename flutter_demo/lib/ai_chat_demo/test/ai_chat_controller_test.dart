import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/ai_chat_demo/application/ai_chat_controller.dart';
import 'package:flutter_demo/ai_chat_demo/application/observe_session_events_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/send_chat_message_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/application/stop_generation_use_case.dart';
import 'package:flutter_demo/ai_chat_demo/domain/entities/chat_message.dart';
import 'package:flutter_demo/ai_chat_demo/domain/entities/reply_stream_event.dart';
import 'package:flutter_demo/ai_chat_demo/domain/entities/session_realtime_event.dart';
import 'package:flutter_demo/ai_chat_demo/domain/repositories/ai_chat_repository.dart';

void main() {
  group('AiChatController', () {
    late _FakeAiChatRepository repository;
    late AiChatController controller;

    setUp(() {
      repository = _FakeAiChatRepository();
      controller = AiChatController(
        sendChatMessageUseCase: SendChatMessageUseCase(repository),
        stopGenerationUseCase: StopGenerationUseCase(repository),
        observeSessionEventsUseCase: ObserveSessionEventsUseCase(repository),
        disposeRepository: repository.dispose,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('实时事件超过上限时，只裁剪 sessionEvents，不误删 messages', () async {
      expect(controller.messages.length, 1);
      expect(controller.messages.first.role, ChatRole.system);

      for (var i = 0; i < 7; i++) {
        repository.emitSessionEvent(
          SystemHintEvent(description: 'event_$i'),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(controller.sessionEvents.length, 6);
      expect(
        controller.sessionEvents.map((e) => e.description).toList(),
        ['event_1', 'event_2', 'event_3', 'event_4', 'event_5', 'event_6'],
      );

      expect(controller.messages.length, 1);
      expect(controller.messages.first.role, ChatRole.system);
      expect(controller.messages.first.id, 'welcome');
    });

    test('sendMessage 后 assistant 占位消息能被 delta 增量拼接', () async {
      await controller.sendMessage('SSE 和 WebSocket 怎么分工？');

      expect(controller.isGenerating, isTrue);
      expect(controller.messages.length, 3);
      expect(controller.messages[1].role, ChatRole.user);
      expect(controller.messages[1].content, 'SSE 和 WebSocket 怎么分工？');
      expect(controller.messages[2].role, ChatRole.assistant);
      expect(controller.messages[2].content, isEmpty);

      final assistantMessageId = controller.messages[2].id;

      repository.emitReplyEvent(
        ReplyStarted(messageId: assistantMessageId),
      );
      repository.emitReplyEvent(
        ReplyDelta(messageId: assistantMessageId, text: 'SSE 负责'),
      );
      repository.emitReplyEvent(
        ReplyDelta(messageId: assistantMessageId, text: '正文流式输出'),
      );
      repository.emitReplyEvent(
        ReplyFinished(messageId: assistantMessageId),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.messages[2].content, 'SSE 负责正文流式输出');
      expect(controller.replySteps, contains('SSE 已建立连接，开始接收模型输出'));
      expect(controller.replySteps, contains('本次回答已完成'));
      expect(controller.isGenerating, isFalse);
    });

    test('stopGenerating 只在生成中触发 stopReply', () async {
      await controller.stopGenerating();
      expect(repository.stopReplyCalls, isEmpty);

      await controller.sendMessage('请停止这次生成');
      final assistantMessageId = controller.messages.last.id;

      await controller.stopGenerating();

      expect(repository.stopReplyCalls, [assistantMessageId]);
    });
  });
}

class _FakeAiChatRepository implements AiChatRepository {
  final StreamController<ReplyStreamEvent> _replyController =
      StreamController<ReplyStreamEvent>.broadcast();
  final StreamController<SessionRealtimeEvent> _sessionController =
      StreamController<SessionRealtimeEvent>.broadcast();

  final List<String> stopReplyCalls = <String>[];
  bool disposed = false;

  void emitReplyEvent(ReplyStreamEvent event) {
    _replyController.add(event);
  }

  void emitSessionEvent(SessionRealtimeEvent event) {
    _sessionController.add(event);
  }

  @override
  Stream<SessionRealtimeEvent> observeSessionEvents() {
    return _sessionController.stream;
  }

  @override
  Future<void> stopReply(String assistantMessageId) async {
    stopReplyCalls.add(assistantMessageId);
  }

  @override
  Stream<ReplyStreamEvent> streamReply({
    required String userInput,
    required String assistantMessageId,
  }) {
    return _replyController.stream;
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_replyController.close());
    unawaited(_sessionController.close());
  }
}