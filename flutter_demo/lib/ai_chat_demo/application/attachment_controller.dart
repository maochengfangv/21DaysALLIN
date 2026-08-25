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
    final images = await pickImageFromGalleryUseCase();
    if (images.isEmpty) return;
    final existingPaths = _selectedImages.map((e) => e.localPath).toSet();
    for (final image in images) {
      if (!existingPaths.contains(image.localPath)) {
        _selectedImages.add(image);
      }
    }
    final length = selectedImages.length;
    debugPrint('[应用层]--->_selectedImages====>$length');

    notifyListeners();
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
