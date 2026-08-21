import 'package:flutter_demo/ai_chat_demo/domain/entities/selected_image_attachment.dart';

abstract class MediaPickerRepository {
  Future<List<SelectedImageAttachment>> pickImagesFromGallery();
}