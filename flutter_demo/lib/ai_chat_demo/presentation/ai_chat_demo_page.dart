import 'package:flutter/material.dart';

import '../application/ai_chat_controller.dart';
import 'widgets/ai_chat_input_bar.dart';
import 'widgets/ai_chat_message_bubble.dart';
import 'widgets/ai_chat_voice_input_sheet.dart';

class AiChatDemoPage extends StatefulWidget {
  const AiChatDemoPage({required this.controller, super.key});

  final AiChatController controller;

  @override
  State<AiChatDemoPage> createState() => _AiChatDemoPageState();
}

class _AiChatDemoPageState extends State<AiChatDemoPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _lastKeyboardVisible = false;

  // ===== 🔴 Bug2修复：细粒度 Notifier 在 initState 创建，dispose 销毁 =====
  late final _MessageListChangeNotifier _messageNotifier;
  late final _InputBarChangeNotifier _inputNotifier;

  @override
  void initState() {
    super.initState();
    _messageNotifier = _MessageListChangeNotifier(widget.controller);
    _inputNotifier = _InputBarChangeNotifier(widget.controller);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _messageScrollController.dispose();
    // 🔴 Bug2修复：细粒度筛选 Notifier 正确 dispose，removeListener + 释放资源
    _messageNotifier.dispose();
    _inputNotifier.dispose();
    widget.controller.dispose();

    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    _dismissKeyboard();
    await widget.controller.sendMessage(text);
  }

  Future<void> _handleOpenVoiceInput() async {
    _dismissKeyboard();
    await widget.controller.startVoiceInput();
    if (!mounted) {
      return;
    }

    final recognizedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return AiChatVoiceInputSheet(
              isListening: controller.isVoiceListening,
              recognizedText: controller.voiceRecognizedText,
              errorText: controller.voiceInputError,
              onCancel: () async {
                await controller.cancelVoiceInput();
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
              onSend: controller.canSendVoiceRecognizedText
                  ? () {
                      final text = controller.consumeVoiceRecognizedText();
                      Navigator.of(sheetContext).pop(text);
                    }
                  : null,
            );
          },
        );
      },
    );

    widget.controller.resetVoiceInput();
    if (!mounted || recognizedText == null || recognizedText.trim().isEmpty) {
      return;
    }
    _inputController.text = recognizedText;
    await _handleSend();
  }

  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) {
        return;
      }
      final position = _messageScrollController.position.maxScrollExtent;
      if (animated) {
        _messageScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat：SSE + WebSocket Demo'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: MediaQuery.viewInsetsOf(context).bottom > 0
                    ? const SizedBox.shrink()
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(height: 1),
                        ],
                      ),
              ),
            ),
            // ========== P0-2 修复1：消息列表只监听 messages 变化 ==========
            Expanded(
              child: AnimatedBuilder(
                animation: _messageNotifier,  // 🔴 Bug2修复：复用 initState 创建的实例
                builder: (context, _) {
                  final controller = widget.controller;
                  final isKeyboardVisible =
                      MediaQuery.viewInsetsOf(context).bottom > 0;

                  if (controller.messages.length != _lastMessageCount) {
                    _lastMessageCount = controller.messages.length;
                    _scheduleScrollToBottom();
                  } else if (isKeyboardVisible && !_lastKeyboardVisible) {
                    _scheduleScrollToBottom();
                  }
                  _lastKeyboardVisible = isKeyboardVisible;

                  return controller.messages.isEmpty
                      ? const Center(child: Text('还没有消息'))
                      : ListView.builder(
                          controller: _messageScrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(12),
                          itemCount: controller.messages.length,
                          itemBuilder: (context, index) {
                            return AiChatMessageBubble(
                              message: controller.messages[index],
                            );
                          },
                        );
                },
              ),
            ),
            const Divider(height: 1),
            // ========== P0-2 修复2：输入栏只监听输入相关变化 ==========
            AnimatedBuilder(
              animation: _inputNotifier,  // 🔴 Bug2修复：复用 initState 创建的实例
              builder: (context, _) {
                final controller = widget.controller;
                return AiChatInputBar(
                  inputController: _inputController,
                  selectedImages: controller.selectedImages,
                  canSend: controller.canSend,
                  canStop: controller.canStop,
                  onSend: _handleSend,
                  onStop: controller.stopGenerating,
                  // ===== Check-images-bug 节点②：Page 层包装 onPickAlbum =====
                  onPickAlbum: () async {
                    final tPage = DateTime.now().millisecondsSinceEpoch;
                    final beforeCount = controller.selectedImages.length;
                    debugPrint(
                      '[Check-images-bug][②AiChatDemoPage] 调用 controller.pickImageFromGallery 前 T=$tPage，当前 selectedImages 数量=$beforeCount',
                    );
                    await controller.pickImageFromGallery();
                    final afterCount = controller.selectedImages.length;
                    final cost =
                        DateTime.now().millisecondsSinceEpoch - tPage;
                    debugPrint(
                      '[Check-images-bug][②AiChatDemoPage] controller.pickImageFromGallery 返回，耗时=${cost}ms，selectedImages 数量=$beforeCount→$afterCount',
                    );
                  },
                  onOpenVoiceInput: _handleOpenVoiceInput,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// P0-2 修复辅助类：细粒度 Listenable 筛选，避免跨域 notify 全量重建
/// 不引入 Provider/Riverpod，Dart SDK 内建即可实现 select() 语义
/// ============================================================
/// 只在「消息列表相关」变化时触发：messages / replySteps / generationState
class _MessageListChangeNotifier extends ChangeNotifier {
  _MessageListChangeNotifier(this._source) {
    _source.addListener(_onChange);
  }
  final AiChatController _source;

  int _lastMessagesLen = -1;
  int _lastStepsLen = -1;
  String _lastGenRuntimeType = '';

  void _onChange() {
    final mLen = _source.messages.length;
    final sLen = _source.replySteps.length;
    final gType = _source.generationState.runtimeType.toString();
    if (mLen != _lastMessagesLen ||
        sLen != _lastStepsLen ||
        gType != _lastGenRuntimeType) {
      _lastMessagesLen = mLen;
      _lastStepsLen = sLen;
      _lastGenRuntimeType = gType;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onChange);
    super.dispose();
  }
}

/// 只在「输入栏相关」变化时触发：selectedImages / canSend/canStop / 语音状态
/// ⚠️ 关键点：sessionEvents / isConnected / unreadCount 变化不会触发这里！
class _InputBarChangeNotifier extends ChangeNotifier {
  _InputBarChangeNotifier(this._source) {
    _source.addListener(_onChange);
  }
  final AiChatController _source;

  int _lastImagesLen = -1;
  bool _lastCanSend = false;
  bool _lastCanStop = false;
  bool _lastVoiceListening = false;
  String _lastVoiceText = '';
  String _lastVoiceError = '';

  void _onChange() {
    final iLen = _source.selectedImages.length;
    final cs = _source.canSend;
    final csp = _source.canStop;
    final vl = _source.isVoiceListening;
    final vt = _source.voiceRecognizedText;
    final ve = _source.voiceInputError ?? '';
    if (iLen != _lastImagesLen ||
        cs != _lastCanSend ||
        csp != _lastCanStop ||
        vl != _lastVoiceListening ||
        vt != _lastVoiceText ||
        ve != _lastVoiceError) {
      _lastImagesLen = iLen;
      _lastCanSend = cs;
      _lastCanStop = csp;
      _lastVoiceListening = vl;
      _lastVoiceText = vt;
      _lastVoiceError = ve;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onChange);
    super.dispose();
  }
}
