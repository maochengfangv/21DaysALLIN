import 'package:flutter/foundation.dart';

import '../ai_chat_controller.dart';

/// 【展示层支持 · Application层】
/// 只在「输入栏相关」维度变化时触发通知：
///   - selectedImages.length（附件选择变化 → 缩略图预览）
///   - canSend / canStop（发送/停止按钮可用性）
///   - 语音状态：isVoiceListening / voiceRecognizedText / voiceInputError
///
/// ⚠️ 核心价值：
///   sessionEvents / isConnected / unreadCount 变化不会触发输入栏重建
///   （WebSocket 高频未读事件与输入栏解耦，这是本次 P0 空档期 Bug 的架构根因修复）
class InputBarChangeNotifier extends ChangeNotifier {
  InputBarChangeNotifier(this._source) {
    _source.addListener(_onChange);
  }

  final AiChatController _source;

  int _lastImagesLen = -1;
  bool _lastCanSend = false;
  bool _lastCanStop = false;
  bool _lastVoiceListening = false;
  String _lastVoiceText = '';
  String _lastVoiceError = '';

  void _onChange() {
    final iLen = _source.selectedImages.length;
    final cs = _source.canSend;
    final csp = _source.canStop;
    final vl = _source.isVoiceListening;
    final vt = _source.voiceRecognizedText;
    final ve = _source.voiceInputError ?? '';
    if (iLen != _lastImagesLen ||
        cs != _lastCanSend ||
        csp != _lastCanStop ||
        vl != _lastVoiceListening ||
        vt != _lastVoiceText ||
        ve != _lastVoiceError) {
      _lastImagesLen = iLen;
      _lastCanSend = cs;
      _lastCanStop = csp;
      _lastVoiceListening = vl;
      _lastVoiceText = vt;
      _lastVoiceError = ve;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onChange);
    super.dispose();
  }
}
