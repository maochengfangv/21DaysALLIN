import 'package:image_picker/image_picker.dart';

class SystemMediaPickerDataSource {
  final ImagePicker _picker = ImagePicker();
  Future<String?> pickImageFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.path;
  }
}
