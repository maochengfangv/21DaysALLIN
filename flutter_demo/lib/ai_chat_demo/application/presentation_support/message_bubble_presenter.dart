import 'package:flutter/material.dart';

import '../../domain/entities/chat_message.dart';

/// 【应用层 · Presentation Support】
/// 单一职责：将领域实体 ChatMessage 翻译成展示层所需的原始数据（三列 Tuple）
/// 使 Widget 层保持纯净，只负责 build → 不掺杂任何 if/switch 判断
///
/// 四层架构边界：
///   ↑ 输入：Domain 层的 ChatMessage（不可变实体）
///   ↓ 输出：展示层可直接消费的 (displayText, bubbleColor, statusHint, borderColor, statusHintColor, isMarkdown)
class MessageBubblePresenter {
  const MessageBubblePresenter(this.context);

  final BuildContext context;

  // -------- 正则（static const → 编译期确定，自定义 lint 不会报 new-in-build） --------
  static final _evalRegex =
      RegExp(r'<\|EVAL\|>[\s\S]*?<\/\|EVAL\|>', multiLine: true);

  /// 启发式 Markdown 特征：ATX 标题 / 围栏代码块 / 表格分隔线 / 有序无序列表 / 引用 / 链接 / 加粗 / 斜体
  static final _markdownFeatureRegex = RegExp(
    r'^( {0,3}#{1,6} +| {0,3}> +| {0,3}-{3,} *$| {0,3}\d+\. +| {0,3}[-*+] +|```[\s\S]*?```|\|[^\n]*\|\s*\n\s*\|[-:| ]+\|)|\[([^\]]+)\]\(([^)]+)\)|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_',
    multiLine: true,
  );

  String _stripEvalTags(String raw) =>
      raw.replaceAll(_evalRegex, '').trimRight();

  /// 气泡主内容与颜色 + 状态副标题
  (String displayText, Color bubbleColor, String? statusHint)
      resolveAppearance({
    required ChatMessage message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final baseUserColor = colorScheme.primaryContainer;
    final baseAssistantColor = colorScheme.surfaceContainerHighest;
    // 🔹 提前做一次 EVAL 清洗并缓存，避免每个分支重复调用
    final sanitized = _stripEvalTags(message.content);

    if (isUser) {
      return (sanitized, baseUserColor, null);
    }

    switch (message.status) {
      case ChatMessageStatus.ready:
        return (
          sanitized.isEmpty ? '...' : sanitized,
          baseAssistantColor,
          null,
        );
      case ChatMessageStatus.pending:
        return (
          '模型思考中...',
          baseAssistantColor,
          '等待模型返回首包',
        );
      case ChatMessageStatus.streaming:
        return (
          sanitized.isEmpty ? '...' : sanitized,
          baseAssistantColor,
          '正在流式输出',
        );
      case ChatMessageStatus.completed:
        return (sanitized, baseAssistantColor, null);
      case ChatMessageStatus.canceled:
        return (
          sanitized.isEmpty ? '本次回答已取消' : sanitized,
          colorScheme.surfaceContainerHighest,
          message.errorMessage ?? '用户已停止生成',
        );
      case ChatMessageStatus.failed:
        return (
          sanitized.isEmpty ? '生成失败，请重试' : sanitized,
          colorScheme.errorContainer,
          message.errorMessage ?? '生成失败',
        );
    }
  }

  /// 气泡描边颜色
  Color resolveBorderColor({required ChatMessage message}) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (message.role) {
      case ChatRole.system:
      case ChatRole.user:
        return Colors.transparent;
      case ChatRole.assistant:
        switch (message.status) {
          case ChatMessageStatus.failed:
            return colorScheme.error.withValues(alpha: 0.4);
          case ChatMessageStatus.canceled:
            return colorScheme.outlineVariant;
          case ChatMessageStatus.streaming:
            return colorScheme.primary.withValues(alpha: 0.35);
          case ChatMessageStatus.pending:
            return colorScheme.primary.withValues(alpha: 0.2);
          case ChatMessageStatus.ready:
          case ChatMessageStatus.completed:
            return Colors.transparent;
        }
    }
  }

  /// 状态副标题文字颜色
  Color resolveStatusHintColor({required ChatMessage message}) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (message.status) {
      case ChatMessageStatus.failed:
        return colorScheme.onErrorContainer;
      case ChatMessageStatus.canceled:
        return colorScheme.onSurfaceVariant;
      case ChatMessageStatus.streaming:
      case ChatMessageStatus.pending:
        return colorScheme.primary;
      case ChatMessageStatus.ready:
      case ChatMessageStatus.completed:
        return colorScheme.onSurfaceVariant;
    }
  }

  /// 内容是否应按 Markdown 渲染。
  ///
  /// 判定优先级（静态可预测，lint 无异议）：
  ///   1. 领域层 `contentFormat` 字段明确声明的 → 直接采信
  ///   2. 否则基于 EVAL 清洗后的文本做启发式特征扫描
  ///      （命中标题/代码块/表格/列表/引用/链接/加粗斜体任一即可）
  bool isMarkdown(ChatMessage message) {
    // 未声明格式 → 退回到内容特征启发式
    final sanitized = _stripEvalTags(message.content);
    return sanitized.isNotEmpty && _markdownFeatureRegex.hasMatch(sanitized);
  }
}
