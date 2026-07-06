import 'package:flutter/material.dart';

import 'pages/baseline_list_page.dart';
import 'pages/optimized_list_page.dart';

final ValueNotifier<bool> performanceOverlayEnabled = ValueNotifier<bool>(false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: performanceOverlayEnabled,
      builder: (context, enabled, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: enabled,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: const HomePage(),
          routes: {
            BaselineListPage.routeName: (_) => const BaselineListPage(),
            OptimizedListPage.routeName: (_) => const OptimizedListPage(),
          },
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Long List Performance Demo'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: performanceOverlayEnabled,
            builder: (context, enabled, _) {
              return Row(
                children: [
                  const Text('Overlay'),
                  Switch(
                    value: enabled,
                    onChanged: (v) => performanceOverlayEnabled.value = v,
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: color.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '对比入口',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Baseline：故意包含常见卡顿因素\nOptimized：懒构建 + 分页 + RepaintBoundary + 局部状态 + 图片缓存/尺寸 + 滚动中占位 + 防抖 + 指标汇总输出',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _open(context, BaselineListPage.routeName),
              child: const Text('进入 Baseline（未优化）'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _open(context, OptimizedListPage.routeName),
              child: const Text('进入 Optimized（已优化）'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '建议在 Profile 模式 + DevTools Performance 面板下对比。\n可先打开 Overlay 开关进行肉眼观察。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}