import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../hybrid/hybrid_channels.dart';
import '../hybrid/hybrid_gateway.dart';
import '../hybrid/hybrid_route.dart';
import 'demo_support.dart';

class PlatformViewDemoPage extends StatefulWidget {
  const PlatformViewDemoPage({super.key, required this.navStyle});

  final NavStyle navStyle;

  @override
  State<PlatformViewDemoPage> createState() => _PlatformViewDemoPageState();
}

class _PlatformViewDemoPageState extends State<PlatformViewDemoPage> {
  static const double _previewWidth = 320;
  static const double _previewHeight = 260;

  final TextEditingController _textController = TextEditingController(
    text: 'Hello from Flutter creationParams',
  );

  int? _platformViewId;
  double _nativeWidth = 220;
  double _nativeHeight = 120;
  double _cornerRadius = 16;
  bool _hidden = false;
  DemoColorOption _backgroundOption = backgroundColorOptions.first;
  DemoColorOption _textColorOption = textColorOptions.first;
  String _syncStatus = '等待 Native View 创建';

  Map<String, Object?> _buildNativeProps() {
    return <String, Object?>{
      'text': _textController.text,
      'width': _nativeWidth,
      'height': _nativeHeight,
      'cornerRadius': _cornerRadius,
      'backgroundColor': colorToHex(_backgroundOption.color),
      'textColor': colorToHex(_textColorOption.color),
      'hidden': _hidden,
    };
  }

  Future<void> _syncNativeView() async {
    final platformViewId = _platformViewId;
    if (platformViewId == null) {
      setState(() {
        _syncStatus = 'Native View 尚未创建';
      });
      return;
    }

    try {
      final response = await HybridChannels.platformViewControl
          .invokeMethod<Object?>('updateNativeView', <String, Object?>{
            'viewId': platformViewId,
            ..._buildNativeProps(),
          });

      if (!mounted) return;
      setState(() {
        _syncStatus = '最近一次同步成功\n${prettyPrintPayload(response)}';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '同步失败: ${error.code} ${error.message ?? ''}'.trim();
      });
    }
  }

  void _handlePlatformViewCreated(int viewId) {
    setState(() {
      _platformViewId = viewId;
      _syncStatus = 'Native View 已创建，viewId=$viewId';
    });
    unawaited(_syncNativeView());
  }

  void _resetState() {
    setState(() {
      _textController.text = 'Hello from Flutter creationParams';
      _nativeWidth = 220;
      _nativeHeight = 120;
      _cornerRadius = 16;
      _hidden = false;
      _backgroundOption = backgroundColorOptions.first;
      _textColorOption = textColorOptions.first;
    });
    unawaited(_syncNativeView());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildColorSelector({
    required String title,
    required List<DemoColorOption> options,
    required DemoColorOption selected,
    required ValueChanged<DemoColorOption> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((DemoColorOption option) {
            final isSelected = selected == option;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              avatar: CircleAvatar(backgroundColor: option.color),
              onSelected: (_) {
                onSelected(option);
                unawaited(_syncNativeView());
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title: ${value.toStringAsFixed(0)}$suffix'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (double nextValue) {
            onChanged(nextValue);
            unawaited(_syncNativeView());
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return HybridPageScaffold(
      title: 'PlatformView Demo',
      navStyle: widget.navStyle,
      onClose: () => unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{'demo': 'platform_view', 'closed': true},
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flutter -> iOS Native View',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('初始属性通过 creationParams 传入；运行中通过 MethodChannel 更新。'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: _previewHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isIOS
                        ? Center(
                            child: SizedBox(
                              width: _previewWidth,
                              height: _previewHeight,
                              child: UiKitView(
                                viewType: HybridChannelNames.nativeViewType,
                                creationParams: _buildNativeProps(),
                                creationParamsCodec:
                                    const StandardMessageCodec(),
                                onPlatformViewCreated:
                                    _handlePlatformViewCreated,
                              ),
                            ),
                          )
                        : const Center(
                            child: Text('当前页面仅在 iOS 宿主中展示 Native PlatformView'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '动态控制面板',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Native UILabel 文本',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _syncNativeView,
                        icon: const Icon(Icons.send),
                      ),
                    ),
                    onSubmitted: (_) => _syncNativeView(),
                  ),
                  const SizedBox(height: 16),
                  _buildColorSelector(
                    title: '背景色',
                    options: backgroundColorOptions,
                    selected: _backgroundOption,
                    onSelected: (DemoColorOption option) {
                      setState(() {
                        _backgroundOption = option;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildColorSelector(
                    title: '文本颜色',
                    options: textColorOptions,
                    selected: _textColorOption,
                    onSelected: (DemoColorOption option) {
                      setState(() {
                        _textColorOption = option;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSlider(
                    title: 'Native 宽度',
                    value: _nativeWidth,
                    min: 120,
                    max: 280,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _nativeWidth = value;
                      });
                    },
                  ),
                  _buildSlider(
                    title: 'Native 高度',
                    value: _nativeHeight,
                    min: 60,
                    max: 180,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _nativeHeight = value;
                      });
                    },
                  ),
                  _buildSlider(
                    title: '圆角',
                    value: _cornerRadius,
                    min: 0,
                    max: 40,
                    suffix: 'pt',
                    onChanged: (double value) {
                      setState(() {
                        _cornerRadius = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    value: _hidden,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏 Native View'),
                    subtitle: const Text('通过 MethodChannel 同步 hidden 状态'),
                    onChanged: (bool value) {
                      setState(() {
                        _hidden = value;
                      });
                      unawaited(_syncNativeView());
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: _syncNativeView,
                        child: const Text('同步到 iOS'),
                      ),
                      OutlinedButton(
                        onPressed: _resetState,
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ResultCard(title: '同步日志', content: _syncStatus),
        ],
      ),
    );
  }
}
