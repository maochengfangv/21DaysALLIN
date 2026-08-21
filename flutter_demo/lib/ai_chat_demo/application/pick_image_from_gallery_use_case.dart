import 'package:flutter_demo/ai_chat_demo/domain/entities/selected_image_attachment.dart';

import '../domain/repositories/media_picker_repository.dart';

class PickImageFromGalleryUseCase {
  final MediaPickerRepository mediaPickerRepository;

  PickImageFromGalleryUseCase(this.mediaPickerRepository);

  Future<List<SelectedImageAttachment>> call() async {
    return await mediaPickerRepository.pickImagesFromGallery();
  }
}