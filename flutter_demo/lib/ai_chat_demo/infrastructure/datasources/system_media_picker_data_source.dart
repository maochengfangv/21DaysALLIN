import 'package:image_picker/image_picker.dart';

class SystemMediaPickerDataSource {
  final ImagePicker _picker = ImagePicker();
   Future<List<XFile>> pickImagesFromGallery() async {
    return _picker.pickMultiImage();
  }
}
