import 'package:flutter/material.dart';

import 'ai_chat_album_button.dart';

class AiChatInputBar extends StatelessWidget {
  final TextEditingController inputController;
  final bool canSend;
  final bool canStop;
  final Future<void> Function() onSend;
  final VoidCallback onStop;
  final Future<void> Function() onPickAlbum;

  const AiChatInputBar({
    super.key,
    required this.inputController,
    required this.canSend,
    required this.canStop,
    required this.onSend,
    required this.onStop,
    required this.onPickAlbum,
  });

  void _showDevelopingToast(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$featureName 开发中....'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: inputController,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '输入一个问题，比如：SSE 和 WebSocket 怎么分工？',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onSend(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AiChatAlbumButton(
                  onPressed: onPickAlbum,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showDevelopingToast(context, '语音输入'),
                  icon: const Icon(Icons.mic_none_outlined),
                  label: const Text('语音'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: canStop
                  ? onStop
                  : (canSend ? onSend : null),
              child: Text(canStop ? '停止' : '发送'),
            ),
          ],
        ),
      ),
    );
  }
}