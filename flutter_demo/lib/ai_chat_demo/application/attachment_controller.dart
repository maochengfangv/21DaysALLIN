import 'package:flutter/foundation.dart';

import '../domain/entities/selected_image_attachment.dart';
import 'pick_image_from_gallery_use_case.dart';

class AttachmentController extends ChangeNotifier {
  AttachmentController({required this.pickImageFromGalleryUseCase});
  final PickImageFromGalleryUseCase pickImageFromGalleryUseCase;

  /// ====状态 仅附件域 ====
  final List<SelectedImageAttachment> _selectedImages = [];

  /// ==== 只读输出 ====
  List<SelectedImageAttachment> get selectedImages =>
      List.unmodifiable(_selectedImages);
  bool get hasSelection => _selectedImages.isNotEmpty;

  Future<void> pickImagesFromGallery() async {
    // ===== Check-images-bug 节点⑤：AttachmentController 核心处理 =====
    final tAttach = DateTime.now().millisecondsSinceEpoch;
    final beforeCount = _selectedImages.length;
    debugPrint(
      '[Check-images-bug][⑤AttachmentController] 进入 pickImagesFromGallery，T=$tAttach，当前已选=$beforeCount，调用 UseCase...',
    );

    // 5-1 调用 UseCase 拿数据
    final tUseCaseStart = DateTime.now().millisecondsSinceEpoch;
    final images = await pickImageFromGalleryUseCase();
    final tUseCaseEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑤AttachmentController] 5-1 UseCase返回，数量=${images.length}，UseCase耗时=${tUseCaseEnd - tUseCaseStart}ms',
    );
    if (images.isEmpty) {
      debugPrint(
        '[Check-images-bug][⑤AttachmentController] 选择为空，提前退出（不会 notifyListeners）',
      );
      return;
    }

    // 5-2 去重逻辑
    final tDedupStart = DateTime.now().millisecondsSinceEpoch;
    final existingPaths = _selectedImages.map((e) => e.localPath).toSet();
    int addedCount = 0;
    final addedPaths = <String>[];
    for (final image in images) {
      if (!existingPaths.contains(image.localPath)) {
        _selectedImages.add(image);
        addedCount++;
        addedPaths.add(image.localPath);
      }
    }
    final tDedupEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑤AttachmentController] 5-2 去重完成，新增=$addedCount/${images.length}，去重耗时=${tDedupEnd - tDedupStart}ms，新增paths=$addedPaths',
    );

    if (addedCount == 0) {
      debugPrint(
        '[Check-images-bug][⑤AttachmentController] 无新增图片，跳过 notifyListeners',
      );
      return;
    }

    // 5-3 发送通知（这一步会触发UI AnimatedBuilder 重建）
    final tNotifyStart = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    final tNotifyEnd = DateTime.now().millisecondsSinceEpoch;
    final afterCount = _selectedImages.length;
    final totalCost = tNotifyEnd - tAttach;
    debugPrint(
      '[Check-images-bug][⑤AttachmentController] 5-3 notifyListeners() 调用，同步耗时=${tNotifyEnd - tNotifyStart}ms（注意：真正的Widget build在这之后的异步帧）',
    );
    debugPrint(
      '[Check-images-bug][⑤AttachmentController] 节点⑤ 完成，总耗时=${totalCost}ms，已选数量=$beforeCount→$afterCount',
    );
  }

  void removeImage(String localPath) {
    _selectedImages.removeWhere((e) => e.localPath == localPath);
    notifyListeners();
  }

  /// Coordinator调用：消息发送后清空
  void clearSelection() {
    if (_selectedImages.isEmpty) return;
    _selectedImages.clear();
    notifyListeners();
  }
}
