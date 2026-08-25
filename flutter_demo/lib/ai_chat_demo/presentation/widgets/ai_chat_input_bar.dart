import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/selected_image_attachment.dart';
import 'ai_chat_album_button.dart';

class AiChatInputBar extends StatelessWidget {
  const AiChatInputBar({
    required this.inputController,
    required this.selectedImages,
    required this.canSend,
    required this.canStop,
    required this.onSend,
    required this.onStop,
    required this.onPickAlbum,
    required this.onOpenVoiceInput,
    super.key,
  });
  final TextEditingController inputController;
  final List<SelectedImageAttachment> selectedImages;
  final bool canSend;
  final bool canStop;
  final Future<void> Function() onSend;
  final VoidCallback onStop;
  final Future<void> Function() onPickAlbum;
  final Future<void> Function() onOpenVoiceInput;

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
    // ===== Check-images-bug 节点⑨：AiChatInputBar build =====
    final tBuild = DateTime.now().millisecondsSinceEpoch;
    final imgCount = selectedImages.length;
    debugPrint(
      '[Check-images-bug][⑨AiChatInputBar] build() 被调用，T=$tBuild，selectedImages 数量=$imgCount',
    );

    // 异步计算：首帧渲染后（图片解码完成后）打终点日志
    if (imgCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tFrame = DateTime.now().millisecondsSinceEpoch;
        final frameCost = tFrame - tBuild;
        debugPrint(
          '[Check-images-bug][⑨AiChatInputBar] addPostFrameCallback 触发，build→首帧渲染完成 耗时=${frameCost}ms，数量=$imgCount',
        );
        // 输出单张平均耗时（粗估，串行 decode 近似正确）
        if (imgCount > 0) {
          debugPrint(
            '[Check-images-bug][⑨AiChatInputBar] 单张图片估算平均解码+渲染耗时=${(frameCost / imgCount).toStringAsFixed(1)}ms/张（若>100ms/张=原图解码导致卡顿）',
          );
        }
      });
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final image in selectedImages)
                        _ThumbnailImage(
                          key: ValueKey(image.localPath),
                          image: image,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                  onPressed: onOpenVoiceInput,
                  icon: const Icon(Icons.mic_none_outlined),
                  label: const Text('语音'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: canStop ? onStop : (canSend ? onSend : null),
              child: Text(canStop ? '停止' : '发送'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== 单独抽离缩略图Widget：便于单独打日志 + 后续优化 cacheWidth =====
class _ThumbnailImage extends StatefulWidget {
  const _ThumbnailImage({
    required super.key,
    required this.image,
  });

  final SelectedImageAttachment image;

  @override
  State<_ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<_ThumbnailImage> {
  late final DateTime _tCreate;

  @override
  void initState() {
    super.initState();
    _tCreate = DateTime.now();
    debugPrint(
      '[Check-images-bug][⑨-Thumb] 单张缩略图 initState，path=${widget.image.localPath}，T=${_tCreate.millisecondsSinceEpoch}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.image.localPath;
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.only(right: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
      ),
      child: Image(
        // ===== 🔴 Bug3修复：ResizeImage显式包裹，100%强制下采样解码 =====
        // 显示尺寸72x72 → 解码尺寸144x144(2x屏) → 解码像素降为原图的 1/(14*10)=1/140
        image: ResizeImage(
          FileImage(File(path)),
          width: 144,
          height: 144,
          allowUpscaling: false,
        ),
        fit: BoxFit.cover,
        // ===== Check-images-bug 关键：frameBuilder 跟踪图片解码完成时机 =====
        frameBuilder: (
          BuildContext context,
          Widget child,
          int? frame,
          bool wasSynchronouslyLoaded,
        ) {
          if (frame != null) {
            final tDone = DateTime.now().millisecondsSinceEpoch;
            final decodeCost = tDone - _tCreate.millisecondsSinceEpoch;
            debugPrint(
              '[Check-images-bug][⑨-Thumb] ✅ 单张解码完成 path=$path，总耗时=${decodeCost}ms（initState→frameBuilder第1帧）',
            );
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            '[Check-images-bug][⑨-Thumb] ❌ 解码失败 path=$path，error=$error',
          );
          return const Icon(Icons.broken_image_outlined, color: Colors.red);
        },
      ),
    );
  }
}
