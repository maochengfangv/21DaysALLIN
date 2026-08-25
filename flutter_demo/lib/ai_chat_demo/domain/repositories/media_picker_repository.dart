import '../entities/selected_image_attachment.dart';

abstract class MediaPickerRepository {
  Future<List<SelectedImageAttachment>> pickImagesFromGallery();
}
