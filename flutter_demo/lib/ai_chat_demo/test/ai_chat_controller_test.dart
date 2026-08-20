import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo/ai_chat_demo/application/ai_chat_controller.dart';
import 'package:flutter_demo/ai_chat_demo/application/chat_generation_state.dart';
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

      expect(controller.generationState, isA<PreparingState>());
      expect(controller.generationLabel, 'SSE 准备中');
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
      expect(controller.generationState, isA<CompletedState>());
      expect(controller.generationLabel, 'SSE 已完成');
      expect(controller.isGenerating, isFalse);
    });

    test('stopGenerating 进入 stopping 态，并在 canceled 事件后结束', () async {
      await controller.stopGenerating();
      expect(repository.stopReplyCalls, isEmpty);

      await controller.sendMessage('请停止这次生成');
      final assistantMessageId = controller.messages.last.id;

      await controller.stopGenerating();
      expect(controller.generationState, isA<StoppingState>());
      expect(controller.generationLabel, 'SSE 停止中');
      expect(repository.stopReplyCalls, [assistantMessageId]);

      repository.emitReplyEvent(
        ReplyCanceled(messageId: assistantMessageId, reason: '用户已停止生成'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.generationState, isA<CanceledState>());
      expect(controller.generationLabel, 'SSE 已取消');
      expect(controller.canSend, isTrue);
      expect(controller.canStop, isFalse);
      expect(controller.replySteps, contains('用户已停止生成'));
    });

    test('ReplyFailed 迁移到 FailedState，并恢复 canSend 禁用 canStop', () async {
      await controller.sendMessage('我会触发一次失败');
      final assistantMessageId = controller.messages.last.id;

      repository.emitReplyEvent(
        ReplyFailed(messageId: assistantMessageId, error: '网络异常'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.generationState, isA<FailedState>());
      expect(controller.generationLabel, 'SSE 失败');
      expect(controller.canSend, isTrue);
      expect(controller.canStop, isFalse);
      expect(controller.isGenerating, isFalse);
      expect(controller.replySteps, contains('生成失败: 网络异常'));

      final failedMessage = controller.messages.last;
      expect(failedMessage.status, ChatMessageStatus.failed);
      expect(failedMessage.errorMessage, '网络异常');
    });

    test('assistant 消息状态按 pending -> streaming -> completed 迁移', () async {
      await controller.sendMessage('消息状态迁移怎么建模？');

      final assistantMessageId = controller.messages.last.id;
      final assistantMessage = controller.messages.last;
      expect(assistantMessage.status, ChatMessageStatus.pending);

      repository.emitReplyEvent(ReplyStarted(messageId: assistantMessageId));
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages.last.status, ChatMessageStatus.streaming);

      repository.emitReplyEvent(
        ReplyDelta(messageId: assistantMessageId, text: '1. 按消息维度'),
      );
      repository.emitReplyEvent(
        ReplyDelta(messageId: assistantMessageId, text: ' 2. 区分 pending/streaming/终态'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages.last.status, ChatMessageStatus.streaming);
      expect(controller.messages.last.content, '1. 按消息维度 2. 区分 pending/streaming/终态');

      repository.emitReplyEvent(ReplyFinished(messageId: assistantMessageId));
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages.last.status, ChatMessageStatus.completed);
      expect(controller.messages.last.errorMessage, isNull);
    });

    test('stopping 后 assistant 消息进入 canceled，并保留取消原因', () async {
      await controller.sendMessage('我准备在半路停止这次生成');
      final assistantMessageId = controller.messages.last.id;
      repository.emitReplyEvent(ReplyStarted(messageId: assistantMessageId));
      repository.emitReplyEvent(
        ReplyDelta(messageId: assistantMessageId, text: '我正在生成前半段'),
      );
      await Future<void>.delayed(Duration.zero);

      await controller.stopGenerating();
      expect(controller.generationState, isA<StoppingState>());
      expect(controller.messages.last.status, ChatMessageStatus.streaming);

      repository.emitReplyEvent(
        ReplyCanceled(messageId: assistantMessageId, reason: '用户主动取消'),
      );
      await Future<void>.delayed(Duration.zero);

      final canceledMessage = controller.messages.last;
      expect(canceledMessage.status, ChatMessageStatus.canceled);
      expect(canceledMessage.errorMessage, '用户主动取消');
      expect(canceledMessage.content, '我正在生成前半段');
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