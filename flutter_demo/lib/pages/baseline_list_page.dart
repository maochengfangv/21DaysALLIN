import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/list_item_baseline.dart';

class BaselineListPage extends StatefulWidget {
  static const routeName = '/baseline';
  const BaselineListPage({super.key});

  @override
  State<BaselineListPage> createState() => _BaselineListPageState();
}

class _BaselineListPageState extends State<BaselineListPage> {
 static const int kItemCount = 200000;

 final Random _random = Random(42);

 int _tick = 0;
 int _highlightId = 0;

 Timer? _timer;

 @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _tick++;
        if (_tick % 2 == 0) {
          _highlightId = _random.nextInt(kItemCount);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

 void _toggleHighlight(int id) {
    setState(() {
      _highlightId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Baseline（未优化） tick=$_tick'),
      actions: [
       ValueListenableBuilder<bool>(
          valueListenable: performanceOverlayEnabled,
          builder: (context, enabled, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                 const Text('Overlay'),
                  Switch(
                    value: enabled,
                    onChanged: (value) {
                      performanceOverlayEnabled.value = value;
                    },
                  ),
                ],
              ),
              );
          },
        ),
      ],
      ),
      body: Column(
        children: [
          Material(
            color:  theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'Baseline 故意包含：整页频繁 setState、较重 item 树、网络图无尺寸缓存控制、无滚动中暂停加载策略',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: kItemCount,
              itemBuilder: (context, index) {
                 final highlight = index == _highlightId;
                return BaselineListItem(
                  key: ValueKey<int>(index),
                  id: index,
                  highlight: highlight,
                  onToggle: () => _toggleHighlight(index),
                );
              },
            ),
          ),
        ]
      )
    );
  }
}