import 'package:flutter/foundation.dart';

final class LoadingController {
  LoadingController._();

  static final LoadingController instance = LoadingController._();

  final ValueNotifier<int> _global = ValueNotifier<int>(0);
  final Map<String, int> _keyed = <String, int>{};

  ValueListenable<int> get listenable => _global;

  bool get isLoading => _global.value > 0;

  void show({String? key}) {
    if (key != null && key.isNotEmpty) {
      _keyed[key] = (_keyed[key] ?? 0) + 1;
    }
    _global.value = _global.value + 1;
  }

  void hide({String? key}) {
    if (_global.value <= 0) return;
    if (key != null && key.isNotEmpty) {
      final current = _keyed[key] ?? 0;
      if (current <= 1) {
        _keyed.remove(key);
      } else {
        _keyed[key] = current - 1;
      }
    }
    _global.value = _global.value - 1;
  }

  int count({String? key}) {
    if (key == null || key.isEmpty) return _global.value;
    return _keyed[key] ?? 0;
  }

  void reset() {
    _keyed.clear();
    _global.value = 0;
  }
}

