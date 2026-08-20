import 'package:flutter/material.dart';

class AiChatInputBar extends StatelessWidget {
  final TextEditingController inputController;
  final bool canSend;
  final bool canStop;
  final Future<void> Function() onSend;
  final VoidCallback onStop;

  const AiChatInputBar({
    super.key,
    required this.inputController,
    required this.canSend,
    required this.canStop,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: inputController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '输入一个问题，比如：SSE 和 WebSocket 怎么分工？',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSend ? onSend : null,
              child: const Text('发送'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: canStop ? onStop : null,
              child: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }
}