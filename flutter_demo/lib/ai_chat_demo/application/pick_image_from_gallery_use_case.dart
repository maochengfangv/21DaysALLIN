import 'package:flutter/foundation.dart';

import '../domain/entities/selected_image_attachment.dart';
import '../domain/repositories/media_picker_repository.dart';

class PickImageFromGalleryUseCase {
  PickImageFromGalleryUseCase(this.mediaPickerRepository);
  final MediaPickerRepository mediaPickerRepository;

  Future<List<SelectedImageAttachment>> call() async {
    // ===== Check-images-bug 节点⑥：UseCase 应用层 =====
    final tUseCase = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑥PickImageFromGalleryUseCase] 进入 UseCase.call，T=$tUseCase，调用 Repository...',
    );
    try {
      final result = await mediaPickerRepository.pickImagesFromGallery();
      final cost = DateTime.now().millisecondsSinceEpoch - tUseCase;
      debugPrint(
        '[Check-images-bug][⑥PickImageFromGalleryUseCase] Repository 返回，数量=${result.length}，UseCase+Repository总耗时=${cost}ms',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint(
        '[Check-images-bug][⑥PickImageFromGalleryUseCase] 异常：$e\n$stackTrace',
      );
      rethrow;
    }
  }
}
