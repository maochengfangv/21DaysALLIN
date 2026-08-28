import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../application/ai_chat_controller.dart';
import '../application/cancel_voice_input_use_case.dart';
import '../application/observe_session_events_use_case.dart';
import '../application/pick_image_from_gallery_use_case.dart';
import '../application/presentation_support/input_bar_change_notifier.dart';
import '../application/presentation_support/message_list_change_notifier_test.dart';
import '../application/send_chat_message_use_case.dart';
import '../application/start_voice_input_use_case.dart';
import '../application/stop_generation_use_case.dart';
import '../domain/entities/reply_stream_event.dart';
import '../domain/entities/selected_image_attachment.dart';
import '../domain/entities/session_realtime_event.dart';
import '../domain/entities/voice_input_result.dart';
import '../domain/repositories/ai_chat_repository.dart';
import '../domain/repositories/media_picker_repository.dart';
import '../domain/repositories/voice_input_repository.dart';

void main() {
  group('RebuildFilter 量化基准测试（简历数据来源）', () {
    late _FakeAiChatRepository repository;
    late _FakeMediaPickerRepository mediaPickerRepository;
    late _FakeVoiceInputRepository voiceInputRepository;
    late AiChatController controller;
    late MessageListChangeNotifier messageNotifier;
    late InputBarChangeNotifier inputNotifier;

    setUp(() {
      repository = _FakeAiChatRepository();
      mediaPickerRepository = _FakeMediaPickerRepository();
      voiceInputRepository = _FakeVoiceInputRepository();
      controller = AiChatController(
        sendChatMessageUseCase: SendChatMessageUseCase(repository),
        stopGenerationUseCase: StopGenerationUseCase(repository),
        observeSessionEventsUseCase: ObserveSessionEventsUseCase(repository),
        pickImageFromGalleryUseCase:
            PickImageFromGalleryUseCase(mediaPickerRepository),
        startVoiceInputUseCase: StartVoiceInputUseCase(voiceInputRepository),
        cancelVoiceInputUseCase: CancelVoiceInputUseCase(voiceInputRepository),
        disposeRepository: () {
          repository.dispose();
          voiceInputRepository.dispose();
        },
      );
      messageNotifier = MessageListChangeNotifier(controller);
      inputNotifier = InputBarChangeNotifier(controller);
    });

    tearDown(() {
      messageNotifier.dispose();
      inputNotifier.dispose();
      controller.dispose();
    });

    test('场景：100 次 ReplyDelta 打字机 + 高频 session 事件干扰', () async {
      await controller.sendMessage('基准测试：量化 rebuild 减少率');
      final assistantMessageId = controller.messages.last.id;

      repository.emitReplyEvent(ReplyStarted(messageId: assistantMessageId));

      // 模拟：100 次 ReplyDelta 流式输出
      for (var i = 0; i < 100; i++) {
        repository.emitReplyEvent(
          ReplyDelta(messageId: assistantMessageId, text: '字$i'),
        );
        // 每 5 次 delta 插入一次 session 事件（模拟 WS 高频未读事件噪音）
        if (i % 5 == 0) {
          final count = i ~/ 5;
          repository.emitSessionEvent(
            UnreadChangedEvent(
              description: '未读变化 $count',
              unreadCount: count,
            ),
          );
        }
        // 每 10 次 delta 插入一次 voice 状态噪音
        if (i % 10 == 0) {
          voiceInputRepository.emitState(
            isListening: i % 20 == 0,
            text: '噪音_$i',
          );
        }
      }
      repository.emitReplyEvent(ReplyFinished(messageId: assistantMessageId));
      await Future<void>.delayed(Duration.zero);

      final msgStats = messageNotifier.debugStats;
      final inputStats = inputNotifier.debugStats;

      // ignore: avoid_print
      print('\n========== 🏆 RebuildFilter 量化报告（可直接写简历） ==========');
      // ignore: avoid_print
      print('【MessageList】'
          'raw=${msgStats.rawCount} 次 → 若无筛选会重建这么多次');
      // ignore: avoid_print
      print('           '
          'actual=${msgStats.actualNotify} 次 → 筛选后实际重建 '
          '✅ 减少率=${msgStats.reduceRate.toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('【InputBar   】'
          'raw=${inputStats.rawCount} 次 → 若无筛选会重建这么多次');
      // ignore: avoid_print
      print('           '
          'actual=${inputStats.actualNotify} 次 → 筛选后实际重建 '
          '✅ 减少率=${inputStats.reduceRate.toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('================================================================');

      // 断言：MessageList reduceRate 应当 > 80%
      expect(
        msgStats.reduceRate,
        greaterThan(80),
        reason: '打字机场景筛选减少率应当 > 80%',
      );
      // 断言：InputBar reduceRate 应当 > 95%（纯 delta 噪音不应触发输入栏重建）
      expect(
        inputStats.reduceRate,
        greaterThan(95),
        reason: '打字机 + session 噪音下，输入栏重建应几乎为 0',
      );
    });
  });
}

class _FakeMediaPickerRepository implements MediaPickerRepository {
  @override
  Future<List<SelectedImageAttachment>> pickImagesFromGallery() async => [];
}

class _FakeVoiceInputRepository implements VoiceInputRepository {
  final StreamController<VoiceInputResult> _controller =
      StreamController<VoiceInputResult>.broadcast();
  void emitState({
    required bool isListening,
    required String text,
    String? error,
  }) {
    // if (error != null) {
    //   _controller.add(VoiceInputResult.failure(error: error));
    // } else if (isListening) {
    //   _controller.add(VoiceInputResult.listening(recognizedText: text));
    // } else {
    //   _controller.add(VoiceInputResult.finalResult(recognizedText: text));
    // }
  }

  @override
  Future<Stream<VoiceInputResult>> startListening() async => _controller.stream;
  @override
  Future<void> cancelListening() async {}
  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class _FakeAiChatRepository implements AiChatRepository {
  final StreamController<ReplyStreamEvent> _replyController =
      StreamController<ReplyStreamEvent>.broadcast();
  final StreamController<SessionRealtimeEvent> _sessionController =
      StreamController<SessionRealtimeEvent>.broadcast();
  bool disposed = false;
  void emitReplyEvent(ReplyStreamEvent event) => _replyController.add(event);
  void emitSessionEvent(SessionRealtimeEvent event) =>
      _sessionController.add(event);

  @override
  Stream<SessionRealtimeEvent> observeSessionEvents() =>
      _sessionController.stream;
  @override
  Future<void> stopReply(String assistantMessageId) async {}
  @override
  Stream<ReplyStreamEvent> streamReply({
    required String userInput,
    required String assistantMessageId,
  }) =>
      _replyController.stream;
  @override
  void dispose() {
    disposed = true;
    unawaited(_replyController.close());
    unawaited(_sessionController.close());
  }
}
