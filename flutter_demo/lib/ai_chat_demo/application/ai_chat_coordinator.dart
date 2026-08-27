import 'package:flutter/cupertino.dart';

import '../domain/entities/chat_message.dart';
import '../domain/entities/selected_image_attachment.dart';
import '../domain/entities/session_realtime_event.dart';
import 'attachment_controller.dart';
import 'chat_generation_state.dart';
import 'message_controller.dart';
import 'session_event_controller.dart';
import 'voice_input_controller.dart';

class AiChatCoordinator extends ChangeNotifier {
  AiChatCoordinator({
    required this.messageController,
    required this.voiceInputController,
    required this.attachmentController,
    required this.sessionEventController,
    this.voiceResultStrategy = VoiceResultStrategy.prefillOnly,
  }) {
    _setupCrossControllerListeners();
  }
  final MessageController messageController;
  final VoiceInputController voiceInputController;
  final AttachmentController attachmentController;
  final SessionEventController sessionEventController;

  /// 策略模式：语音识别结果的处理策略
  /// 后续可扩展为 enum + 配置化（产品AB测无需改代码）
  final VoiceResultStrategy voiceResultStrategy;

  /// 架构核心 跨域交互集中管理
  void _setupCrossControllerListeners() {
    // ===== 场景1：语音识别完成 → 填入待发送文本 / 自动发送 =====
    voiceInputController.addListener(_onVoiceStateChanged);
    // ===== 场景2：消息发送成功 → 清空已选附件（可配置策略） =====
    messageController.addListener(_onMessageStateChanged);
    // ===== 🔴 Bug1修复：Coordinator 必须监听4个子域的全部通知 =====
    // attachmentController.selectedImages 变化 → 触发 Coordinator 转发给 UI
    attachmentController.addListener(notifyListeners);
    // sessionEventController.unread/isConnected 变化 → 触发 Coordinator 转发
    sessionEventController.addListener(notifyListeners);
  }

  void _onVoiceStateChanged() {
    if (!voiceInputController.hasFinalResult) return;

    switch (voiceResultStrategy) {
      case VoiceResultStrategy.prefillOnly:
        final text = voiceInputController.consumeRecognizedText();
        messageController.prefillInput(text);
      case VoiceResultStrategy.autoSend:
        final text = voiceInputController.consumeRecognizedText();
        if (text.isNotEmpty) {
          sendMessageWithAttachments(text);
        }
    }
  }

  /// 🔴 核心修复：消息状态变化 → **无条件**向上转发通知 + 业务副作用
  /// 原 Bug：只有 Preparing 分支有逻辑，streaming 期间 notifyListeners 完全丢失
  void _onMessageStateChanged() {
    // 副作用：idel/completed → Preparing 时清空已选附件（发送流程触发）
    if (messageController.generationState is PreparingState) {
      if (attachmentController.hasSelection) {
        attachmentController.clearSelection();
      }
    }
    // ✅ 必须无条件转发！每次 ReplyDelta 追加内容都要经过这里通知上层 UI
    notifyListeners();
  }

  // 【Facade 层】对UI层暴露的统一API（保持原AiChatController接口兼容）
// --- 转发 MessageController ---
  List<ChatMessage> get messages => messageController.messages;
  List<String> get replySteps => messageController.replySteps;
  ChatGenerationState get generationState => messageController.generationState;
  bool get isGenerating => messageController.isGenerating;
  bool get canSend => messageController.canSend;
  bool get canStop => messageController.canStop;
  String get generationLabel => messageController.generationLabel;
  String? get currentAssistantMessageId =>
      messageController.currentAssistantMessageId;
  String get prefilledInput => messageController.prefilledInput;
  Future<void> sendMessageWithAttachments(String input) async {
    await messageController.sendMessage(
      input,
      attachments: attachmentController.selectedImages,
    );
  }

  Future<void> stopGenerating() => messageController.stopGenerating();

  // --- 转发 VoiceInputController ---

  bool get isVoiceListening => voiceInputController.isVoiceListening;
  String get voiceRecognizedText => voiceInputController.voiceRecognizedText;
  String? get voiceInputError => voiceInputController.voiceInputError;
  bool get canSendVoiceRecognizedText =>
      voiceInputController.canSendRecognizedText;
  Future<void> startVoiceInput() => voiceInputController.startListening();
  Future<void> cancelVoiceInput() => voiceInputController.cancelListening();
  String consumeVoiceRecognizedText() =>
      voiceInputController.consumeRecognizedText();
  void resetVoiceInput() => voiceInputController.reset();
  // --- 转发 AttachmentController ---
  List<SelectedImageAttachment> get selectedImages =>
      attachmentController.selectedImages;

  Future<void> pickImageFromGallery() async {
    // ===== Check-images-bug 节点④：Coordinator 层 =====
    final tCoord = DateTime.now().millisecondsSinceEpoch;
    final before = attachmentController.selectedImages.length;
    debugPrint(
      '[Check-images-bug][④AiChatCoordinator] 进入 Coordinator.pickImageFromGallery，T=$tCoord，selectedImages 数量=$before，转发给 AttachmentController',
    );
    try {
      await attachmentController.pickImagesFromGallery();
    } finally {
      final after = attachmentController.selectedImages.length;
      final cost = DateTime.now().millisecondsSinceEpoch - tCoord;
      debugPrint(
        '[Check-images-bug][④AiChatCoordinator] AttachmentController 返回，Coordinator 耗时=${cost}ms，selectedImages 数量=$before→$after',
      );
    }
  }

  void removeSelectedImage(String localPath) =>
      attachmentController.removeImage(localPath);

  // --- 转发 SessionEventController ---
  List<SessionRealtimeEvent> get sessionEvents =>
      sessionEventController.sessionEvents;
  bool get isConnected => sessionEventController.isConnected;
  int get unreadCount => sessionEventController.unreadCount;
  void clearUnreadCount() => sessionEventController.clearUnread();

  // --- 预留给Provider/Riverpod的 select() 精细重建用 ---
  MessageController get messageOnly => messageController;
  VoiceInputController get voiceOnly => voiceInputController;
  AttachmentController get attachmentOnly => attachmentController;
  SessionEventController get sessionOnly => sessionEventController;

  @override
  void dispose() {
    // 管理生命周期: 按注册逆序 removeListener
    messageController.removeListener(_onMessageStateChanged);
    voiceInputController.removeListener(_onVoiceStateChanged);
    // 🔴 Bug1修复：移除 attachment/session 的转发监听
    attachmentController.removeListener(notifyListeners);
    sessionEventController.removeListener(notifyListeners);

    messageController.dispose();
    voiceInputController.dispose();
    attachmentController.dispose();
    sessionEventController.dispose();

    super.dispose();
  }
}

/// 语音识别结果处理策略
enum VoiceResultStrategy {
  prefillOnly, // 只填充输入框，需用户手动点击发送（默认，更安全）
  autoSend, // 识别完成自动发送（适合场景：驾驶模式/无障碍模式）
}
