import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar_demo/domain/entities/user_profile.dart';
import 'providers.dart';

class RiverpodDemoPage extends ConsumerWidget {
  const RiverpodDemoPage({super.key});

  static const String routeName = '/riverpod-demo';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int counter = ref.watch(counterProvider);
    final AsyncValue<UserProfile> profileAsync =
        ref.watch(userProfileFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod 最少验证')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _CounterCard(counter: counter),
          const SizedBox(height: 16),
          _ProfileCard(profileAsync: profileAsync),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(userProfileFutureProvider),
            child: const Text('刷新用户头像（ref.invalidate）'),
          ),
        ],
      ),
    );
  }
}

/// StateProvider 演示：计数器的增减
class _CounterCard extends ConsumerWidget {
  const _CounterCard({required this.counter});

  final int counter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Text('StateProvider：简单可变状态（计数器）'),
            const SizedBox(height: 8),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: () => ref.read(counterProvider.notifier).state--,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: () => ref.read(counterProvider.notifier).state++,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// FutureProvider 演示：AsyncValue 自动处理 loading / error / data
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profileAsync});

  final AsyncValue<UserProfile> profileAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => SizedBox(
            height: 120,
            child: Center(child: Text('加载失败：$error')),
          ),
          data: (UserProfile profile) => Column(
            children: <Widget>[
              ClipOval(
                child: Image.network(
                  profile.avatarUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.person, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('ID: ${profile.id}'),
            ],
          ),
        ),
      ),
    );
  }
}
