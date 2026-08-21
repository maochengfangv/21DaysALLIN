import '../domain/repositories/media_picker_repository.dart';

class PickImageFromGalleryUseCase {
  final MediaPickerRepository mediaPickerRepository;

  PickImageFromGalleryUseCase(this.mediaPickerRepository);

  Future<String?> call() async {
    return await mediaPickerRepository.pickImageFromGallery();
  }
}