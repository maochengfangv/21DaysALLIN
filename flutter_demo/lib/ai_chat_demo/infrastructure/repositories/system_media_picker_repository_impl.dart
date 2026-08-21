import 'package:flutter_demo/ai_chat_demo/domain/repositories/media_picker_repository.dart';

import '../../domain/entities/selected_image_attachment.dart';
import '../datasources/system_media_picker_data_source.dart';

class SystemMediaPickerRepositoryImpl implements MediaPickerRepository {
  
  final SystemMediaPickerDataSource dataSource;
  SystemMediaPickerRepositoryImpl({
    required this.dataSource
  });
  
  @override
  Future<List<SelectedImageAttachment>> pickImagesFromGallery() async {
    final files = await dataSource.pickImagesFromGallery();
    return files
        .map(
          (file) => SelectedImageAttachment(
            id: file.path,
            localPath: file.path,
          ),
        )
        .toList();
  }


}