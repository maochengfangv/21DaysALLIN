import 'package:flutter/foundation.dart';

import '../ai_chat_controller.dart';
import 'message_list_change_notifier_test.dart';

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

  // ===== P0 补强：rebuild 量化计数器（与 MessageList 对称） =====
  int _rawEventCount = 0;
  int _actualNotifyCount = 0;
  int _lastReportedRawCount = 0;
  static const int _reportInterval = 50;

  /// 【量化指标导出】输入栏 Notifier 的筛选统计
  RebuildFilterStats get debugStats => RebuildFilterStats(
        name: 'InputBar',
        rawCount: _rawEventCount,
        actualNotify: _actualNotifyCount,
      );

  void _onChange() {
    if (kDebugMode) {
      _rawEventCount++;
    }
    final iLen = _source.selectedImages.length;
    final cs = _source.canSend;
    final csp = _source.canStop;
    final vl = _source.isVoiceListening;
    final vt = _source.voiceRecognizedText;
    final ve = _source.voiceInputError ?? '';
    final shouldNotify = iLen != _lastImagesLen ||
        cs != _lastCanSend ||
        csp != _lastCanStop ||
        vl != _lastVoiceListening ||
        vt != _lastVoiceText ||
        ve != _lastVoiceError;
    if (shouldNotify) {
      _lastImagesLen = iLen;
      _lastCanSend = cs;
      _lastCanStop = csp;
      _lastVoiceListening = vl;
      _lastVoiceText = vt;
      _lastVoiceError = ve;
      if (kDebugMode) {
        _actualNotifyCount++;
      }
      notifyListeners();
    }

    if (kDebugMode &&
        _rawEventCount - _lastReportedRawCount >= _reportInterval) {
      _lastReportedRawCount = _rawEventCount;
      debugPrint(debugStats.toString());
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onChange);
    if (kDebugMode && _rawEventCount > 0) {
      debugPrint('[Perf][InputBar] dispose 时最终统计: ${debugStats.summary}');
    }
    super.dispose();
  }
}
