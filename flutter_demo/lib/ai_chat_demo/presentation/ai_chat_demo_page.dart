import 'package:flutter/material.dart';

import '../application/ai_chat_controller.dart';
import 'widgets/ai_chat_input_bar.dart';
import 'widgets/ai_chat_message_bubble.dart';
import 'widgets/ai_chat_voice_input_sheet.dart';

class AiChatDemoPage extends StatefulWidget {
  const AiChatDemoPage({super.key, required this.controller});

  final AiChatController controller;

  @override
  State<AiChatDemoPage> createState() => _AiChatDemoPageState();
}

class _AiChatDemoPageState extends State<AiChatDemoPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _lastKeyboardVisible = false;

  @override
  void dispose() {
    _inputController.dispose();
    _messageScrollController.dispose();
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

        if (controller.messages.length != _lastMessageCount) {
          _lastMessageCount = controller.messages.length;
          _scheduleScrollToBottom();
        } else if (isKeyboardVisible && !_lastKeyboardVisible) {
          _scheduleScrollToBottom();
        }
        _lastKeyboardVisible = isKeyboardVisible;

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
                    child: isKeyboardVisible
                        ? const SizedBox.shrink()
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(height: 1),
                            ],
                          ),
                  ),
                ),
                Expanded(
                  child: controller.messages.isEmpty
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
                        ),
                ),
                const Divider(height: 1),
                AiChatInputBar(
                  inputController: _inputController,
                  selectedImages: controller.selectedImages,
                  canSend: controller.canSend,
                  canStop: controller.canStop,
                  onSend: _handleSend,
                  onStop: controller.stopGenerating,
                  onPickAlbum: controller.pickImageFromGallery,
                  onOpenVoiceInput: _handleOpenVoiceInput,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
