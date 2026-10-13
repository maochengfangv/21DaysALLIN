import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'counter_bloc.dart';

class BlocDemoPage extends StatelessWidget {
  const BlocDemoPage({super.key});

  static const routeName = '/bloc-demo';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterBloc(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Bloc 最少代码实践')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('你点了这么多次：'),
              BlocBuilder<CounterBloc, CounterState>(
                builder: (context, state) => Text(
                  '${state.count}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: () => context.read<CounterBloc>().add(Increment()),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () => context.read<CounterBloc>().add(Decrement()),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
