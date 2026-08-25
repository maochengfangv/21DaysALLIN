import 'package:flutter/material.dart';

class AiChatAlbumButton extends StatelessWidget {
  const AiChatAlbumButton({
    required this.onPressed,
    super.key,
  });
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed == null
          ? null
          : () async {
              // ===== Check-images-bug 节点①：用户点击相册按钮 T0 =====
              final t0 = DateTime.now().millisecondsSinceEpoch;
              debugPrint(
                '[Check-images-bug][①UiClick] T0=$t0 用户点击相册按钮，开始执行 onPressed',
              );
              try {
                await onPressed!();
              } finally {
                final totalCost = DateTime.now().millisecondsSinceEpoch - t0;
                debugPrint(
                  '[Check-images-bug][①UiClick] 相册按钮 onPressed 同步执行完毕，总耗时=${totalCost}ms (注意：真正的UI渲染在这之后)',
                );
              }
            },
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('相册'),
    );
  }
}
