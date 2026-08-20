import 'package:flutter/material.dart';

import 'pages/animation_demo_page.dart';
import 'pages/baseline_list_page.dart';
import 'pages/industry_animation_controls_page.dart';
import 'pages/optimized_list_page.dart';
import 'pages/thread_demo_page.dart';
import 'pages/avatar_demo_four_layers_page.dart';
import 'ai_chat_demo/ai_chat_demo_module.dart';
import 'ai_chat_demo/presentation/ai_chat_demo_page.dart';

final ValueNotifier<bool> performanceOverlayEnabled = ValueNotifier<bool>(false);

const String aiChatDemoRouteName = '/ai-chat-demo';

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
            AnimationDemoPage.routeName: (_) => const AnimationDemoPage(),
            ThreadDemoPage.routeName: (_) => const ThreadDemoPage(),
            IndustryAnimationControlsPage.routeName: (_) =>
                const IndustryAnimationControlsPage(),
            AvatarDemoFourLayersPage.routeName: (_) =>
                const AvatarDemoFourLayersPage(),
            aiChatDemoRouteName: (_) => AiChatDemoPage(
                  controller: buildAiChatController(),
                ),
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
        title: const Text('Flutter Demo Playground'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _open(context, AnimationDemoPage.routeName),
              child: const Text('🎬 Flutter 动画体系 Demo（面试复习）'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  _open(context, IndustryAnimationControlsPage.routeName),
              child: const Text('✨ 大厂 Flutter 动画控件 Demo'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _open(context, ThreadDemoPage.routeName),
              child: const Text('🧵 Flutter 线程 / Isolate Demo'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  _open(context, AvatarDemoFourLayersPage.routeName),
              child: const Text('🧱 四层架构：获取用户头像 Demo'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _open(context, aiChatDemoRouteName),
              child: const Text('🤖 AI Chat：SSE + WebSocket Demo'),
            ),
            const SizedBox(height: 16),
            const Text(
              '建议在 Profile 模式 + DevTools Performance 面板下对比。\n可先打开 Overlay 开关进行肉眼观察。',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}