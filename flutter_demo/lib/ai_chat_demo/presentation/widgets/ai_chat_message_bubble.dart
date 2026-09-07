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
    // P1-2 优化：每条气泡独立 RepaintBoundary，隔离滚动/邻居重绘
    return RepaintBoundary(
      key: ValueKey<String>('bubble_${message.id}'),
      child: _buildBubble(context),
    );
  }

  Widget _buildBubble(BuildContext context) {
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
    // P1-2：内容区独立 RepaintBoundary，Markdown AST 构建不影响外层气泡
    if (presenter.isMarkdown(message)) {
      return RepaintBoundary(
        child: MarkdownBody(
          data: displayText,
          selectable: true,
          onTapLink: (text, href, title) => _handleTapLink(context, href),
          sizedImageBuilder: _markdownSizedImageBuilder, // 预留：图片下采样/缓存钩子
        ),
      );
    }
    return RepaintBoundary(child: Text(displayText));
  }

  /// Markdown 图片加载钩子（P1-2 预留，使用新版 sizedImageBuilder API）
  ///   - 生产环境：在此接入 ResizeImage/ImageCache 分级/下采样
  ///   - Demo 环境：返回默认 Image.network 即可
  ///   - [MarkdownImageConfig] 包含 uri/title/alt/width/height 字段
  Widget _markdownSizedImageBuilder(MarkdownImageConfig config) {
    // TODO(perf): 接入 ResizeImage(Image.network(...), width: 640) 下采样
    // TODO(perf): 接入 MemoryImageCache 分级监听系统内存压力清理
    try {
      if (config.uri.scheme == 'http' || config.uri.scheme == 'https') {
        return Image.network(
          config.uri.toString(),
          width: config.width,
          height: config.height,
          errorBuilder: (_, e, __) => const Text('[图片加载失败]'),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      }
      return Text('[无法加载图片: ${config.uri.scheme}]');
    } catch (_) {
      return const Text('[图片加载失败]');
    }
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
