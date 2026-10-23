// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flutter Demo Playground';

  @override
  String get compareSectionTitle => '对比入口';

  @override
  String get compareSectionDesc => 'Baseline：故意包含常见卡顿因素\nOptimized：懒构建 + 分页 + RepaintBoundary + 局部状态 + 图片缓存/尺寸 + 滚动中占位 + 防抖 + 指标汇总输出';

  @override
  String get enterBaseline => '进入 Baseline（未优化）';

  @override
  String get enterOptimized => '进入 Optimized（已优化）';

  @override
  String get performanceTip => '建议在 Profile 模式 + DevTools Performance 面板下对比。\n可先打开 Overlay 开关进行肉眼观察。';
}
