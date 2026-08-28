import 'package:flutter/foundation.dart';

import '../../domain/entities/chat_message.dart';
import '../ai_chat_controller.dart';

/// 【展示层支持 · Application层】
/// 只在「消息列表相关」维度变化时触发通知：
///   - messages.length（消息数量增删，列表重绘）
///   - replySteps.length（生成状态步骤变更）
///   - generationState.runtimeType（生成状态机迁移：Idle/Preparing/Streaming/...）
///
/// ⚠️ 边界契约：
///   - 不访问 BuildContext / Widget / dart:ui
///   - 可跨多个 Page 复用（如：AiChatMultiWindowPage / AiChatEmbeddedPage）
///   - 可直接在 test/ 目录下 import 写单测
class MessageListChangeNotifier extends ChangeNotifier {
  MessageListChangeNotifier(this._source) {
    _source.addListener(_onChange);
  }

  final AiChatController _source;

  int _lastMessagesLen = -1;
  int _lastStepsLen = -1;
  String _lastGenRuntimeType = '';
  int _lastAssistantContentLen = -1;

  // ===== P0 补强：rebuild 量化计数器（kDebugMode 生效，release 零开销） =====
  /// 源 Controller 触发 onChange 的总次数（= 不做筛选时的重建次数）
  int _rawEventCount = 0;

  /// 经过维度筛选后实际 notifyListeners 的次数（= 真实重建次数）
  int _actualNotifyCount = 0;

  /// 最近一次打印统计时的 rawEventCount（避免刷屏）
  int _lastReportedRawCount = 0;
  static const int _reportInterval = 50; // 每 50 次源事件打印一次报告

  /// 【量化指标导出】消息列表 Notifier 的筛选统计
  /// 返回 (rawCount, actualCount, filteredCount, reduceRate%)
  RebuildFilterStats get debugStats => RebuildFilterStats(
        name: 'MessageList',
        rawCount: _rawEventCount,
        actualNotify: _actualNotifyCount,
      );

  void _onChange() {
    if (kDebugMode) {
      _rawEventCount++;
    }
    final mLen = _source.messages.length;
    final sLen = _source.replySteps.length;
    final gType = _source.generationState.runtimeType.toString();
    // 🔴 流式输出关键修复：计算所有 assistant 消息的内容总长度
    // 每次 ReplyDelta 追加内容时，此值都会变化，确保打字机效果触发 UI 重建
    final assistantContentLen = _source.messages
        .where((e) => e.role == ChatRole.assistant)
        .fold<int>(0, (sum, e) => sum + e.content.length);
    final shouldNotify = mLen != _lastMessagesLen ||
        sLen != _lastStepsLen ||
        gType != _lastGenRuntimeType ||
        assistantContentLen != _lastAssistantContentLen;
    if (shouldNotify) {
      _lastMessagesLen = mLen;
      _lastStepsLen = sLen;
      _lastGenRuntimeType = gType;
      _lastAssistantContentLen = assistantContentLen;
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
      debugPrint('[Perf][MessageList] dispose 时最终统计: ${debugStats.summary}');
    }
    super.dispose();
  }
}

/// ============================================================
/// rebuild 筛选量化指标容器（跨多个 Notifier 复用的公共数据结构）
/// ============================================================
class RebuildFilterStats {
  const RebuildFilterStats({
    required this.name,
    required this.rawCount,
    required this.actualNotify,
  });

  final String name;
  final int rawCount;
  final int actualNotify;

  int get filteredCount => rawCount - actualNotify;

  /// 重建减少率：(原始 - 实际) / 原始 * 100%
  /// rawCount=0 时返回 0 避免除零
  double get reduceRate =>
      rawCount == 0 ? 0 : filteredCount / rawCount * 100;

  String get summary =>
      '$name: raw=$rawCount actual=$actualNotify '
      'filtered=$filteredCount reduce=${reduceRate.toStringAsFixed(1)}%';

  @override
  String toString() => '[Perf][RebuildFilter] $summary';
}
