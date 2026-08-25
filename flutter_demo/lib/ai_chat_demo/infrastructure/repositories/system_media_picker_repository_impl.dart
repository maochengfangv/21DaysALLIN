import 'package:flutter/foundation.dart';

import '../../domain/entities/selected_image_attachment.dart';
import '../../domain/repositories/media_picker_repository.dart';
import '../datasources/system_media_picker_data_source.dart';

class SystemMediaPickerRepositoryImpl implements MediaPickerRepository {
  SystemMediaPickerRepositoryImpl({required this.dataSource});
  final SystemMediaPickerDataSource dataSource;

  @override
  Future<List<SelectedImageAttachment>> pickImagesFromGallery() async {
    // ===== Check-images-bug 节点⑦：Repository 基础设施层 =====
    final tRepo = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑦SystemMediaPickerRepositoryImpl] 进入 Repository，T=$tRepo，调用 DataSource(系统ImagePicker插件)...',
    );

    // 7-1 调 DataSource（调用系统 ImagePicker 插件）
    final tDsStart = DateTime.now().millisecondsSinceEpoch;
    final files = await dataSource.pickImagesFromGallery();
    final tDsEnd = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑦SystemMediaPickerRepositoryImpl] 7-1 DataSource(系统Picker)返回，数量=${files.length}，**系统Picker插件耗时=${tDsEnd - tDsStart}ms**',
    );

    // 7-2 XFile → SelectedImageAttachment 映射
    final tMapStart = DateTime.now().millisecondsSinceEpoch;
    final result = files
        .map(
          (file) => SelectedImageAttachment(
            id: file.path,
            localPath: file.path,
          ),
        )
        .toList();
    final tMapEnd = DateTime.now().millisecondsSinceEpoch;
    final totalCost = tMapEnd - tRepo;
    debugPrint(
      '[Check-images-bug][⑦SystemMediaPickerRepositoryImpl] 7-2 XFile→Entity 映射完成，数量=${result.length}，映射耗时=${tMapEnd - tMapStart}ms，Repository 总耗时=${totalCost}ms',
    );
    return result;
  }
}
