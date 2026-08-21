import 'package:flutter_demo/ai_chat_demo/domain/repositories/media_picker_repository.dart';

import '../datasources/system_media_picker_data_source.dart';

class SystemMediaPickerRepositoryImpl implements MediaPickerRepository {
  
  final SystemMediaPickerDataSource dataSource;
  SystemMediaPickerRepositoryImpl({
    required this.dataSource
  });
  
  @override
  Future<String?> pickImageFromGallery() async {
    return await dataSource.pickImageFromGallery();
  }
}