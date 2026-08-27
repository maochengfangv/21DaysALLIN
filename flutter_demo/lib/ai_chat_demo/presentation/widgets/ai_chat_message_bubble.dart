import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/presentation_support/message_bubble_presenter.dart';
import '../../domain/entities/chat_message.dart';

class AiChatMessageBubble extends StatelessWidget {
  const AiChatMessageBubble({
    required this.message,
    super.key,
  });
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    // 系统消息居中展示（时间/提示类）
    if (message.role == ChatRole.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // === Presentation 层只做「取值 + 渲染」，判断逻辑全下沉到 Presenter ===
    final presenter = MessageBubblePresenter(context);
    final theme = Theme.of(context);
    final (displayText, bubbleColor, statusHint) = presenter.resolveAppearance(
      message: message,
    );
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: presenter.resolveBorderColor(message: message)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContent(context, presenter, displayText),
            if (statusHint != null) ...[
              const SizedBox(height: 6),
              Text(
                statusHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: presenter.resolveStatusHintColor(message: message),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 纯渲染分支：Markdown / PlainText
  Widget _buildContent(
    BuildContext context,
    MessageBubblePresenter presenter,
    String displayText,
  ) {
    if (presenter.isMarkdown(message)) {
      return MarkdownBody(
        data: displayText,
        selectable: true,
        onTapLink: (text, href, title) => _handleTapLink(context, href),
      );
    }
    return Text(displayText);
  }

  /// 链接跳转：统一错误提示，不打印任何日志
  Future<void> _handleTapLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) {
      _showLinkToast(context, '链接地址无效');
      return;
    }
    try {
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        if (context.mounted) _showLinkToast(context, '暂时无法打开链接');
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) _showLinkToast(context, '打开链接失败');
    } catch (_) {
      if (context.mounted) _showLinkToast(context, '打开链接失败，请稍后重试');
    }
  }

  void _showLinkToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
