import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../hybrid/hybrid_gateway.dart';
import '../hybrid/hybrid_route.dart';

final class DemoColorOption {
  const DemoColorOption(this.label, this.color);

  final String label;
  final Color color;
}

const List<DemoColorOption> backgroundColorOptions = <DemoColorOption>[
  DemoColorOption('Coral', Color(0xFFFF6B6B)),
  DemoColorOption('Ocean', Color(0xFF4D96FF)),
  DemoColorOption('Mint', Color(0xFF4ECDC4)),
  DemoColorOption('Amber', Color(0xFFFFC75F)),
  DemoColorOption('Violet', Color(0xFF845EC2)),
];

const List<DemoColorOption> textColorOptions = <DemoColorOption>[
  DemoColorOption('White', Colors.white),
  DemoColorOption('Black', Colors.black87),
  DemoColorOption('Navy', Color(0xFF1D3557)),
  DemoColorOption('Berry', Color(0xFFB5179E)),
];

String createRequestId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

String prettyPrintPayload(Object? payload) {
  if (payload == null) return 'null';
  if (payload is Map || payload is List) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
  return payload.toString();
}

String colorToHex(Color color) {
  String hex(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${hex(color.alpha)}${hex(color.red)}${hex(color.green)}${hex(color.blue)}';
}

/// 混合页面统一外壳。
///
/// - `navStyle == flutter`：Flutter 自绘 AppBar，Native 隐藏导航栏。
/// - `navStyle == native`：Native 提供导航栏，Flutter 仅渲染内联头部。
/// - `navStyle == none`：全屏沉浸，无任何导航栏。
///
/// 返回能力由 Navigator 栈实时推导，并与宿主 BackDispatcher 通过 canPopV2 同步。
class HybridPageScaffold extends StatelessWidget {
  const HybridPageScaffold({
    super.key,
    required this.title,
    required this.navStyle,
    required this.child,
    this.onClose,
  });

  final String title;
  final NavStyle navStyle;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    void handleClose() {
      if (onClose != null) {
        onClose!();
        return;
      }
      unawaited(
        HybridGateway.instance.closeFlutter(
          result: <String, Object?>{'message': 'closed from $title'},
        ),
      );
    }

    void handleBack() {
      unawaited(HybridGateway.instance.popOrClose());
    }

    Widget content = child;

    if (navStyle != NavStyle.flutter) {
      content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (canPop)
                  TextButton(
                    onPressed: handleBack,
                    child: const Text('Back'),
                  )
                else
                  const SizedBox(width: 64),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: handleClose, child: const Text('Close')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      );
    }

    if (navStyle == NavStyle.none) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: navStyle == NavStyle.flutter
          ? AppBar(
              automaticallyImplyLeading: false,
              leading: canPop
                  ? IconButton(
                      onPressed: handleBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
              title: Text(title),
              actions: [
                IconButton(onPressed: handleClose, icon: const Icon(Icons.close)),
              ],
            )
          : null,
      body: content,
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(content),
          ],
        ),
      ),
    );
  }
}
