import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';

import 'ai_chat_demo/ai_chat_demo_module.dart';
import 'ai_chat_demo/presentation/ai_chat_demo_page.dart';
import 'bloc_demo/bloc_demo_page.dart';
import 'getx_demo/getx_demo_binding.dart';
import 'getx_demo/getx_demo_page.dart';
import 'l10n/app_localizations.dart';
import 'pages/animation_demo_page.dart';
import 'pages/avatar_demo_four_layers_page.dart';
import 'pages/baseline_list_page.dart';
import 'pages/industry_animation_controls_page.dart';
import 'pages/isolate_method_channel_demo_page.dart';
import 'pages/optimized_list_page.dart';
import 'pages/thread_demo_page.dart';
import 'riverpod/riverpod_demo_page.dart';

final ValueNotifier<bool> performanceOverlayEnabled =
    ValueNotifier<bool>(false);

const String aiChatDemoRouteName = '/ai-chat-demo';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DemoApp()));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: performanceOverlayEnabled,
      builder: (context, enabled, _) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: enabled,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: const HomePage(),
          getPages: [
            GetPage(
              name: GetxDemoPage.routeName,
              page: () => const GetxDemoPage(),
              binding: GetxDemoBinding(),
            ),
          ],
          routes: {
            BaselineListPage.routeName: (_) => const BaselineListPage(),
            OptimizedListPage.routeName: (_) => const OptimizedListPage(),
            AnimationDemoPage.routeName: (_) => const AnimationDemoPage(),
            ThreadDemoPage.routeName: (_) => const ThreadDemoPage(),
            IsolateMethodChannelDemoPage.routeName: (_) =>
                const IsolateMethodChannelDemoPage(),
            IndustryAnimationControlsPage.routeName: (_) =>
                const IndustryAnimationControlsPage(),
            AvatarDemoFourLayersPage.routeName: (_) =>
                const AvatarDemoFourLayersPage(),
            aiChatDemoRouteName: (_) => AiChatDemoPage(
                  controller: buildAiChatController(),
                ),
            RiverpodDemoPage.routeName: (_) => const RiverpodDemoPage(),
            BlocDemoPage.routeName: (_) => const BlocDemoPage(),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
                    l10n.compareSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.compareSectionDesc),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _open(context, BaselineListPage.routeName),
            child: Text(l10n.enterBaseline),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _open(context, OptimizedListPage.routeName),
            child: Text(l10n.enterOptimized),
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
                _open(context, IsolateMethodChannelDemoPage.routeName),
            child: const Text('📡 Isolate -> MethodChannel 闭环 Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _open(context, AvatarDemoFourLayersPage.routeName),
            child: const Text('🧱 四层架构：获取用户头像 Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _open(context, aiChatDemoRouteName),
            child: const Text('🤖 AI Chat：SSE + WebSocket Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _open(context, RiverpodDemoPage.routeName),
            child: const Text('🌊 Riverpod 最少验证 Demo'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Get.toNamed(GetxDemoPage.routeName),
            child: const Text('⚡️ GetX 最少代码实践'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _open(context, BlocDemoPage.routeName),
            child: const Text('🧊 Bloc 最少代码实践'),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.performanceTip,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
