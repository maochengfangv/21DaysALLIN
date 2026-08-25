import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SystemVoiceInputDataSource {
  final SpeechToText _speechToText = SpeechToText();
  final StreamController<(String text, bool isFinal)> _resultController =
      StreamController<(String text, bool isFinal)>.broadcast();

  bool _initialized = false;
  String _latestText = '';

  Future<Stream<(String text, bool isFinal)>> startListening() async {
    final available = _initialized ||
        await _speechToText.initialize(
          onError: _handleError,
          onStatus: _handleStatus,
        );
    _initialized = available;

    if (!available) {
      throw Exception('麦克风权限未开启或当前设备暂不支持语音识别');
    }

    _latestText = '';
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }

    await _speechToText.listen(
      onResult: _handleResult,
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      pauseFor: const Duration(seconds: 2),
    );

    return _resultController.stream;
  }

  void _handleResult(SpeechRecognitionResult result) {
    _latestText = result.recognizedWords;
    _resultController.add((_latestText, result.finalResult));
    if (result.finalResult) {
      unawaited(_speechToText.stop());
    }
  }

  void _handleStatus(String status) {
    if ((status == 'done' || status == 'notListening') &&
        _latestText.isNotEmpty) {
      _resultController.add((_latestText, true));
    }
  }

  Future<void> cancelListening() async {
    _latestText = '';
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }

  void dispose() {
    unawaited(_resultController.close());
  }

  void _handleError(SpeechRecognitionError errorNotification) {
    _resultController.addError(Exception(errorNotification.errorMsg));
  }
}
