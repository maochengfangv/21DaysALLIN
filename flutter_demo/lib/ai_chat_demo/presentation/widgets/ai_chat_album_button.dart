import 'package:flutter/material.dart';

class AiChatAlbumButton extends StatelessWidget {
  final Future<void> Function()? onPressed;

  const AiChatAlbumButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('相册'),
    );
  }
}