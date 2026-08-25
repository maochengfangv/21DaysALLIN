
import 'package:flutter/material.dart';

import 'ai_chat_voice_ripple.dart';

class AiChatVoiceInputSheet extends StatelessWidget {
  final bool isListening;
  final String recognizedText;
  final String? errorText;
  final Future<void> Function() onCancel;
  final VoidCallback? onSend;

  const AiChatVoiceInputSheet({
    super.key,
    required this.isListening,
    required this.recognizedText,
    required this.errorText,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '语音输入',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isListening
                  ? Column(
                      key: const ValueKey('voice-listening'),
                      children: [
                        const AiChatVoiceRipple(),
                        const SizedBox(height: 16),
                        Text(
                          '正在识别，请开始说话…',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '识别完成后会自动停止并展示文字',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('voice-result'),
                      children: [
                        Icon(
                          Icons.text_snippet_outlined,
                          size: 34,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 120),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            recognizedText.trim().isEmpty
                                ? (errorText ?? '未识别到清晰语音，请重试')
                                : recognizedText,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
            ),
            if (errorText != null && errorText!.isNotEmpty && !isListening) ...[
              const SizedBox(height: 12),
              Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSend,
                    child: const Text('发送'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}