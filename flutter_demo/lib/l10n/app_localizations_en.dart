// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutter Demo Playground';

  @override
  String get compareSectionTitle => 'Comparison Entry';

  @override
  String get compareSectionDesc => 'Baseline: intentionally includes common jank factors\nOptimized: lazy build + pagination + RepaintBoundary + local state + image cache/size + placeholder while scrolling + debounce + metrics summary';

  @override
  String get enterBaseline => 'Open Baseline';

  @override
  String get enterOptimized => 'Open Optimized';

  @override
  String get performanceTip => 'Compare in Profile mode with the DevTools Performance panel.\nYou can first enable the Overlay switch for a visual check.';
}
