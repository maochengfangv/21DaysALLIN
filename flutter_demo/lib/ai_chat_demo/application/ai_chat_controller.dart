import 'package:flutter/foundation.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/selected_image_attachment.dart';
import '../domain/entities/session_realtime_event.dart';
import '../domain/repositories/ai_chat_repository.dart';
import '../domain/repositories/media_picker_repository.dart';
import '../domain/repositories/voice_input_repository.dart';
import 'ai_chat_coordinator.dart';
import 'attachment_controller.dart';
import 'cancel_voice_input_use_case.dart';
import 'chat_generation_state.dart';
import 'message_controller.dart';
import 'observe_session_events_use_case.dart';
import 'pick_image_from_gallery_use_case.dart';
import 'send_chat_message_use_case.dart';
import 'session_event_controller.dart';
import 'start_voice_input_use_case.dart';
import 'stop_generation_use_case.dart';
import 'voice_input_controller.dart';

/// ============================================================
/// 【兼容层】保持原接口签名不变，UI层零迁移成本
/// 内部委托给 AiChatCoordinator 及其 4 个子 Controller
///
/// ⚠️  Deprecated Warning：
///     新代码请直接使用 AiChatCoordinator，本类仅作过渡
///     可在一个迭代后通过全局查找替换移除
/// ============================================================
@Deprecated('请使用 AiChatCoordinator 替代，详见架构拆分文档')
class AiChatController extends ChangeNotifier {
  // ============================================================
  // 【便捷工厂】基于 Repository 直接构造（DI容器中常用）
  // ============================================================
  factory AiChatController.fromRepositories({
    required AiChatRepository chatRepository,
    required MediaPickerRepository mediaPickerRepository,
    required VoiceInputRepository voiceInputRepository,
    required VoidCallback disposeRepository,
  }) {
    return AiChatController(
      sendChatMessageUseCase: SendChatMessageUseCase(chatRepository),
      stopGenerationUseCase: StopGenerationUseCase(chatRepository),
      observeSessionEventsUseCase: ObserveSessionEventsUseCase(chatRepository),
      pickImageFromGalleryUseCase:
          PickImageFromGalleryUseCase(mediaPickerRepository),
      startVoiceInputUseCase: StartVoiceInputUseCase(voiceInputRepository),
      cancelVoiceInputUseCase: CancelVoiceInputUseCase(voiceInputRepository),
      disposeRepository: disposeRepository,
    );
  }
  AiChatController({
    required SendChatMessageUseCase sendChatMessageUseCase,
    required StopGenerationUseCase stopGenerationUseCase,
    required ObserveSessionEventsUseCase observeSessionEventsUseCase,
    required PickImageFromGalleryUseCase pickImageFromGalleryUseCase,
    required StartVoiceInputUseCase startVoiceInputUseCase,
    required CancelVoiceInputUseCase cancelVoiceInputUseCase,
    required VoidCallback disposeRepository,
  }) : this._withCoordinator(
          coordinator: AiChatCoordinator(
            messageController: MessageController(
              sendChatMessageUseCase: sendChatMessageUseCase,
              stopGenerationUseCase: stopGenerationUseCase,
            ),
            voiceInputController: VoiceInputController(
              startVoiceInputUseCase: startVoiceInputUseCase,
              cancelVoiceInputUseCase: cancelVoiceInputUseCase,
            ),
            attachmentController: AttachmentController(
              pickImageFromGalleryUseCase: pickImageFromGalleryUseCase,
            ),
            sessionEventController: SessionEventController(
              observeSessionEventsUseCase: observeSessionEventsUseCase,
            ),
          ),
          disposeRepository: disposeRepository,
        );

  /// 推荐直接注入Coordinator的构造函数（新代码路径）
  AiChatController._withCoordinator({
    required AiChatCoordinator coordinator,
    required this.disposeRepository,
  }) : _coordinator = coordinator {
    _coordinator.addListener(_forwardNotifications);
  }

  final AiChatCoordinator _coordinator;
  final VoidCallback disposeRepository;

  // ===== 监听转发：保持UI层notifyListeners行为一致 =====
  void _forwardNotifications() => notifyListeners();

  // ===== 全部转发至 Coordinator =====
  List<ChatMessage> get messages => _coordinator.messages;
  List<String> get replySteps => _coordinator.replySteps;
  ChatGenerationState get generationState => _coordinator.generationState;
  bool get isGenerating => _coordinator.isGenerating;
  bool get canSend => _coordinator.canSend;
  bool get canStop => _coordinator.canStop;
  String get generationLabel => _coordinator.generationLabel;
  String? get currentAssistantMessageId =>
      _coordinator.currentAssistantMessageId;
  bool get isConnected => _coordinator.isConnected;
  int get unreadCount => _coordinator.unreadCount;
  bool get isVoiceListening => _coordinator.isVoiceListening;
  String get voiceRecognizedText => _coordinator.voiceRecognizedText;
  String? get voiceInputError => _coordinator.voiceInputError;
  bool get canSendVoiceRecognizedText =>
      _coordinator.canSendVoiceRecognizedText;
  List<SelectedImageAttachment> get selectedImages =>
      _coordinator.selectedImages;
  List<SessionRealtimeEvent> get sessionEvents => _coordinator.sessionEvents;

  Future<void> sendMessage(String input) =>
      _coordinator.sendMessageWithAttachments(input);

  Future<void> stopGenerating() => _coordinator.stopGenerating();

  Future<void> pickImageFromGallery() async {
    // ===== Check-images-bug 节点③：兼容层 AiChatController =====
    final tCompat = DateTime.now().millisecondsSinceEpoch;
    final before = _coordinator.selectedImages.length;
    debugPrint(
      '[Check-images-bug][③AiChatController] 进入兼容层 pickImageFromGallery，T=$tCompat，selectedImages 数量=$before，转发给 Coordinator',
    );
    try {
      await _coordinator.pickImageFromGallery();
    } finally {
      final after = _coordinator.selectedImages.length;
      final cost = DateTime.now().millisecondsSinceEpoch - tCompat;
      debugPrint(
        '[Check-images-bug][③AiChatController] Coordinator 返回，兼容层耗时=${cost}ms，selectedImages 数量=$before→$after',
      );
    }
  }

  Future<void> startVoiceInput() => _coordinator.startVoiceInput();

  Future<void> cancelVoiceInput() => _coordinator.cancelVoiceInput();

  String consumeVoiceRecognizedText() =>
      _coordinator.consumeVoiceRecognizedText();

  void resetVoiceInput() => _coordinator.resetVoiceInput();

  void removeSelectedImage(String localPath) =>
      _coordinator.removeSelectedImage(localPath);

  @override
  void dispose() {
    _coordinator.removeListener(_forwardNotifications);
    _coordinator.dispose();
    disposeRepository();
    super.dispose();
  }
}
