import 'package:flutter/material.dart';

import '../application/ai_chat_controller.dart';
import 'widgets/ai_chat_input_bar.dart';
import 'widgets/ai_chat_message_bubble.dart';
import 'widgets/ai_chat_top_panel.dart';

class AiChatDemoPage extends StatefulWidget {

  final AiChatController controller;

  const AiChatDemoPage({super.key, required this.controller});

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

  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) return;
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
        final latestEvents = controller.sessionEvents.reversed.take(3).toList();
        final latestSteps = controller.replySteps.reversed.take(4).toList();

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
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AiChatTopPanel(
                              isConnected: controller.isConnected,
                              unreadCount: controller.unreadCount,
                              generationLabel: controller.generationLabel,
                              latestSteps: latestSteps,
                              latestEvents: latestEvents
                                  .map((e) => e.description)
                                  .toList(),
                            ),
                            const Divider(height: 1),
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
                          return AiChatMessageBubble(message: controller.messages[index]);
                        },
                      ),
              ),
              const Divider(height: 1),
              AiChatInputBar(
                inputController: _inputController,
                canSend: controller.canSend,
                canStop: controller.canStop,
                onSend: _handleSend,
                onStop: controller.stopGenerating,
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

