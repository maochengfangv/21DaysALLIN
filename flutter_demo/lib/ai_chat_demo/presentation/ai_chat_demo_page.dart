import 'package:flutter/material.dart';

import '../application/ai_chat_controller.dart';
import '../domain/entities/chat_message.dart';

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
                            _buildTopPanel(context, controller),
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
                          return _MessageBubble(message: controller.messages[index]);
                        },
                      ),
              ),
              const Divider(height: 1),
              _buildInputBar(context, controller),
            ],
          ),
          ),
        );
      },
    );
  }
    Widget _buildTopPanel(BuildContext context, AiChatController controller) {
      
      final colorScheme = Theme.of(context).colorScheme;
      final latestEvents = controller.sessionEvents.reversed.take(3).toList();

      final latestSteps = controller.replySteps.reversed.take(4).toList();
      return Container(
      color: colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: CircleAvatar(
                  backgroundColor:
                      controller.isConnected ? Colors.green : Colors.red,
                  radius: 5,
                ),
                label: Text(
                  controller.isConnected ? 'WebSocket 已连接' : 'WebSocket 未连接',
                ),
              ),
              Chip(label: Text('未读数: ${controller.unreadCount}')),
              Chip(
                label: Text(
                  controller.generationLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoCard(
            title: 'SSE 回答流',
            items: latestSteps.isEmpty ? const ['等待发送消息'] : latestSteps,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            title: 'WebSocket 事件流',
            items: latestEvents.isEmpty
                ? const ['等待实时事件']
                : latestEvents.map((e) => e.description).toList(),
          ),
        ],
      ),
    );

    }

     Widget _buildInputBar(BuildContext context, AiChatController controller) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '输入一个问题，比如：SSE 和 WebSocket 怎么分工？',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: controller.canSend ? _handleSend : null,
              child: const Text('发送'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: controller.canStop ? controller.stopGenerating : null,
              child: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }
}





class _InfoCard extends StatelessWidget {
  final String title;

  final List<String> items;
  const _InfoCard({
required this.title,
required this.items

  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (displayText, bubbleColor, statusHint) = _resolveAppearance(context, isUser);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _resolveBorderColor(colorScheme),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText),
            if (statusHint != null) ...[
              const SizedBox(height: 6),
              Text(
                statusHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _resolveStatusHintColor(colorScheme),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String displayText, Color bubbleColor, String? statusHint) _resolveAppearance(
    BuildContext context,
    bool isUser,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseUserColor = colorScheme.primaryContainer;
    final baseAssistantColor = colorScheme.surfaceContainerHighest;

    if (isUser) {
      return (message.content, baseUserColor, null);
    }

    switch (message.status) {
      case ChatMessageStatus.ready:
        return (message.content.isEmpty ? '...' : message.content, baseAssistantColor, null);
      case ChatMessageStatus.pending:
        return ('模型思考中...', baseAssistantColor, '等待模型返回首包');
      case ChatMessageStatus.streaming:
        return (message.content.isEmpty ? '...' : message.content, baseAssistantColor, '正在流式输出');
      case ChatMessageStatus.completed:
        return (message.content, baseAssistantColor, null);
      case ChatMessageStatus.canceled:
        return (
          message.content.isEmpty ? '本次回答已取消' : message.content,
          colorScheme.surfaceContainerHighest,
          message.errorMessage ?? '用户已停止生成',
        );
      case ChatMessageStatus.failed:
        return (
          message.content.isEmpty ? '生成失败，请重试' : message.content,
          colorScheme.errorContainer,
          message.errorMessage ?? '生成失败',
        );
    }
  }

  Color _resolveBorderColor(ColorScheme colorScheme) {
    switch (message.role) {
      case ChatRole.system:
        return Colors.transparent;
      case ChatRole.user:
        return Colors.transparent;
      case ChatRole.assistant:
        switch (message.status) {
          case ChatMessageStatus.failed:
            return colorScheme.error.withValues(alpha: 0.4);
          case ChatMessageStatus.canceled:
            return colorScheme.outlineVariant;
          case ChatMessageStatus.streaming:
            return colorScheme.primary.withValues(alpha: 0.35);
          case ChatMessageStatus.pending:
            return colorScheme.primary.withValues(alpha: 0.2);
          case ChatMessageStatus.ready:
          case ChatMessageStatus.completed:
            return Colors.transparent;
        }
    }
  }

  Color _resolveStatusHintColor(ColorScheme colorScheme) {
    switch (message.status) {
      case ChatMessageStatus.failed:
        return colorScheme.onErrorContainer;
      case ChatMessageStatus.canceled:
        return colorScheme.onSurfaceVariant;
      case ChatMessageStatus.streaming || ChatMessageStatus.pending:
        return colorScheme.primary;
      case ChatMessageStatus.ready || ChatMessageStatus.completed:
        return colorScheme.onSurfaceVariant;
    }
  }
}
