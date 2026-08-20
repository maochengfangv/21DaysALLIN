import 'package:flutter/material.dart';

import '../../domain/entities/chat_message.dart';

class AiChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const AiChatMessageBubble({
    super.key,
    required this.message,
  });

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
    final (displayText, bubbleColor, statusHint) = _resolveAppearance(
      context,
      isUser,
    );

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

  (String displayText, Color bubbleColor, String? statusHint)
      _resolveAppearance(
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
        return (
          message.content.isEmpty ? '...' : message.content,
          baseAssistantColor,
          null,
        );
      case ChatMessageStatus.pending:
        return ('模型思考中...', baseAssistantColor, '等待模型返回首包');
      case ChatMessageStatus.streaming:
        return (
          message.content.isEmpty ? '...' : message.content,
          baseAssistantColor,
          '正在流式输出',
        );
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
      case ChatMessageStatus.streaming:
      case ChatMessageStatus.pending:
        return colorScheme.primary;
      case ChatMessageStatus.ready:
      case ChatMessageStatus.completed:
        return colorScheme.onSurfaceVariant;
    }
  }
}