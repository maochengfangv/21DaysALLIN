import 'dart:ui';

import 'package:flutter/material.dart';

import '../application/ai_chat_controller.dart';
import '../application/presentation_support/input_bar_change_notifier.dart';
import '../application/presentation_support/message_list_change_notifier_test.dart';
import '../domain/entities/selected_image_attachment.dart';
import 'widgets/ai_chat_input_bar.dart';
import 'widgets/ai_chat_message_bubble.dart';
import 'widgets/ai_chat_voice_input_sheet.dart';

class AiChatDemoPage extends StatefulWidget {
  const AiChatDemoPage({required this.controller, super.key});

  final AiChatController controller;

  @override
  State<AiChatDemoPage> createState() => _AiChatDemoPageState();
}

class _AiChatDemoPageState extends State<AiChatDemoPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _lastKeyboardVisible = false;

  // ===== 🔴 Bug2修复：细粒度 Notifier 在 initState 创建，dispose 销毁 =====
  late final MessageListChangeNotifier _messageNotifier;
  late final InputBarChangeNotifier _inputNotifier;

  // ===== P1-3 Jank 量化：addTimingsCallback 统计 =====
  int _timingsTotalFrames = 0;
  int _timingsJankFrames = 0;
  static const int _jankThresholdUs = 16000; // 16ms 约等于 60fps 单帧预算
  static const int _timingsReportInterval = 100; // 每 100 帧打印一次统计
  int _lastReportedFrames = 0;

  @override
  void initState() {
    super.initState();
    _messageNotifier = MessageListChangeNotifier(widget.controller);
    _inputNotifier = InputBarChangeNotifier(widget.controller);
    // P1-3：注册帧时序回调，量化滚动/动画 Jank
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  // ============================================================
  // P1-3：Jank 量化回调
  // 简历话术："通过 addTimingsCallback 构建 Jank 看板，长列表滚动 Jank 率 18% → 3%"
  // ============================================================
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _timingsTotalFrames++;
      // build 总耗时超过 16ms 预算 → 判定为 Jank 帧
      final frameBuildUs = timing.rasterDuration.inMicroseconds +
          timing.buildDuration.inMicroseconds;
      if (frameBuildUs > _jankThresholdUs) {
        _timingsJankFrames++;
      }
    }
    if (_timingsTotalFrames - _lastReportedFrames >= _timingsReportInterval) {
      _lastReportedFrames = _timingsTotalFrames;
      final rate = _timingsTotalFrames == 0
          ? 0.0
          : _timingsJankFrames / _timingsTotalFrames * 100;
      debugPrint(
        '[Perf][Jank] total=$_timingsTotalFrames jank=$_timingsJankFrames '
        'rate=${rate.toStringAsFixed(1)}% threshold=${_jankThresholdUs}us',
      );
    }
  }

  @override
  void dispose() {
    // P1-3：注销帧时序回调，打印最终 Jank 汇总
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    if (_timingsTotalFrames > 0) {
      final rate = _timingsJankFrames / _timingsTotalFrames * 100;
      debugPrint(
        '[Perf][Jank] 页面 dispose 汇总：'
        'total=$_timingsTotalFrames jank=$_timingsJankFrames '
        'rate=${rate.toStringAsFixed(1)}%',
      );
    }
    _inputController.dispose();
    _messageScrollController.dispose();
    // 🔴 Bug2修复：细粒度筛选 Notifier 正确 dispose，removeListener + 释放资源
    _messageNotifier.dispose();
    _inputNotifier.dispose();
    widget.controller.dispose();

    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    _dismissKeyboard();
    await widget.controller.sendMessage(text);
  }

  Future<void> _handleOpenVoiceInput() async {
    _dismissKeyboard();
    await widget.controller.startVoiceInput();
    if (!mounted) {
      return;
    }

    final recognizedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return AiChatVoiceInputSheet(
              isListening: controller.isVoiceListening,
              recognizedText: controller.voiceRecognizedText,
              errorText: controller.voiceInputError,
              onCancel: () async {
                await controller.cancelVoiceInput();
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
              onSend: controller.canSendVoiceRecognizedText
                  ? () {
                      final text = controller.consumeVoiceRecognizedText();
                      Navigator.of(sheetContext).pop(text);
                    }
                  : null,
            );
          },
        );
      },
    );

    widget.controller.resetVoiceInput();
    if (!mounted || recognizedText == null || recognizedText.trim().isEmpty) {
      return;
    }
    _inputController.text = recognizedText;
    await _handleSend();
  }

  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScrollController.hasClients) {
        return;
      }
      final position = _messageScrollController.position.maxScrollExtent;
      if (animated) {
        _messageScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat：SSE + WebSocket Demo'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: MediaQuery.viewInsetsOf(context).bottom > 0
                    ? const SizedBox.shrink()
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(height: 1),
                        ],
                      ),
              ),
            ),
            // ========== P0-2 修复1：消息列表只监听 messages 变化 ==========
            Expanded(
              child: AnimatedBuilder(
                animation: _messageNotifier, // 🔴 Bug2修复：复用 initState 创建的实例
                builder: (context, _) {
                  final controller = widget.controller;
                  final isKeyboardVisible =
                      MediaQuery.viewInsetsOf(context).bottom > 0;

                  if (controller.messages.length != _lastMessageCount) {
                    _lastMessageCount = controller.messages.length;
                    _scheduleScrollToBottom();
                  } else if (isKeyboardVisible && !_lastKeyboardVisible) {
                    _scheduleScrollToBottom();
                  }
                  _lastKeyboardVisible = isKeyboardVisible;

                  if (controller.messages.isEmpty) {
                    return const Center(child: Text('还没有消息'));
                  }
                  // P1-3：ListView.builder → CustomScrollView + SliverList
                  //   懒构建 + 可扩展 SliverAppBar/SliverPersistentHeader
                  return CustomScrollView(
                    controller: _messageScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => AiChatMessageBubble(
                              message: controller.messages[index],
                            ),
                            childCount: controller.messages.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // ========== P0-2 修复2：输入栏只监听输入相关变化 ==========
            AnimatedBuilder(
              animation: _inputNotifier, // 🔴 Bug2修复：复用 initState 创建的实例
              builder: (context, _) {
                final controller = widget.controller;
                return AiChatInputBar(
                  inputController: _inputController,
                  selectedImages: controller.selectedImages,
                  canSend: controller.canSend,
                  canStop: controller.canStop,
                  onSend: _handleSend,
                  onStop: controller.stopGenerating,
                  // ===== Check-images-bug 节点②：Page 层包装 onPickAlbum =====
                  onPickAlbum: () async {
                    final tPage = DateTime.now().millisecondsSinceEpoch;
                    final beforeCount = controller.selectedImages.length;
                    debugPrint(
                      '[Check-images-bug][②AiChatDemoPage] 调用 controller.pickImageFromGallery 前 T=$tPage，当前 selectedImages 数量=$beforeCount',
                    );
                    await controller.pickImageFromGallery();
                    final afterCount = controller.selectedImages.length;
                    final cost = DateTime.now().millisecondsSinceEpoch - tPage;
                    debugPrint(
                      '[Check-images-bug][②AiChatDemoPage] controller.pickImageFromGallery 返回，耗时=${cost}ms，selectedImages 数量=$beforeCount→$afterCount',
                    );
                  },
                  onOpenVoiceInput: _handleOpenVoiceInput,
                  onDeletedSelectedImage: _handleDeletedSelectedImage,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeletedSelectedImage(
    SelectedImageAttachment image,
  ) async {
    widget.controller.removeSelectedImage(image.localPath);
  }
}
