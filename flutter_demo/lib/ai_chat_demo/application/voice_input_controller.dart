import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities/voice_input_result.dart';
import 'cancel_voice_input_use_case.dart';
import 'start_voice_input_use_case.dart';

/// 【单一职责】只管语音ASR输入
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    required this.startVoiceInputUseCase,
    required this.cancelVoiceInputUseCase,
  });

  final StartVoiceInputUseCase startVoiceInputUseCase;
  final CancelVoiceInputUseCase cancelVoiceInputUseCase;

  // ===== 状态：仅语音域 =====
  StreamSubscription<VoiceInputResult>? _voiceInputSubscription;
  bool _isVoiceListening = false;
  String _voiceRecognizedText = '';
  String? _voiceInputError;
  bool _hasFinalResult = false;

  // ===== 只读输出 =====
  bool get isVoiceListening => _isVoiceListening;
  String get voiceRecognizedText => _voiceRecognizedText;
  String? get voiceInputError => _voiceInputError;
  bool get hasFinalResult => _hasFinalResult;
  bool get canSendRecognizedText =>
      !_isVoiceListening && _voiceRecognizedText.trim().isNotEmpty;

  Future<void> startListening() async {
    await _voiceInputSubscription?.cancel();
    _voiceRecognizedText = '';
    _voiceInputError = null;
    _isVoiceListening = true;
    _hasFinalResult = false;
    notifyListeners();

    try {
      final stream = await startVoiceInputUseCase();
      _voiceInputSubscription = stream.listen(
        (result) {
          _voiceRecognizedText = result.text;
          _isVoiceListening = !result.isFinal;
          if (result.isFinal) _hasFinalResult = true;
          notifyListeners();
        },
        onError: (Object error) {
          _voiceInputError = '语音识别失败：$error';
          _isVoiceListening = false;
          notifyListeners();
        },
      );
    } catch (error) {
      _voiceInputError = '语音识别启动失败：$error';
      _isVoiceListening = false;
      notifyListeners();
    }
  }

  Future<void> cancelListening() async {
    await _voiceInputSubscription?.cancel();
    _voiceInputSubscription = null;
    await cancelVoiceInputUseCase();
    _voiceRecognizedText = '';
    _voiceInputError = null;
    _isVoiceListening = false;
    _hasFinalResult = false;
    notifyListeners();
  }

  /// Coordinator调用：消费识别结果并清空
  String consumeRecognizedText() {
    final text = _voiceRecognizedText.trim();
    _voiceRecognizedText = '';
    _voiceInputError = null;
    _isVoiceListening = false;
    _hasFinalResult = false;
    notifyListeners();
    return text;
  }

  void reset() {
    _voiceRecognizedText = '';
    _voiceInputError = null;
    _isVoiceListening = false;
    _hasFinalResult = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceInputSubscription?.cancel();
    super.dispose();
  }
}
