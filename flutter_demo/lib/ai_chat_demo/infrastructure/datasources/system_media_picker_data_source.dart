import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class SystemMediaPickerDataSource {
  final ImagePicker _picker = ImagePicker();

  Future<List<XFile>> pickImagesFromGallery() async {
    // ===== Check-images-bug 节点⑧：DataSource 系统插件层（最底层） =====
    final tDs = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Check-images-bug][⑧SystemMediaPickerDataSource] 进入 DataSource，T=$tDs，调用 ImagePicker.pickMultiImage() **系统原生调用开始**',
    );
    try {
      // ===== P0-1 修复：Picker侧就下采样 + 跳过元数据读取，避免全尺寸HEIC/PNG拷贝
      // maxWidth=1024 足够生成 144px 缩略图，imageQuality=85 体积减60%
      // requestFullMetadata=false 跳过读取EXIF/定位信息（iOS模拟器提速关键）
      final result = await _picker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      final cost = DateTime.now().millisecondsSinceEpoch - tDs;
      debugPrint(
        '[Check-images-bug][⑧SystemMediaPickerDataSource] ImagePicker插件返回，数量=${result.length}，**原生Picker+数据搬运总耗时=${cost}ms**',
      );
      return result;
    } catch (e, stackTrace) {
      debugPrint(
        '[Check-images-bug][⑧SystemMediaPickerDataSource] ImagePicker 插件异常：$e\n$stackTrace',
      );
      rethrow;
    }
  }
}
