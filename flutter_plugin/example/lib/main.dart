import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_plugin/flutter_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _resultText = 'Unknown';
  final FlutterPluginApi _api = FlutterPluginApi();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final result = await _api.getPlatformVersion();
    final text = result.isOk
        ? result.data ?? ''
        : 'code=${result.code.code} message=${result.message}';

    if (!mounted) return;

    setState(() {
      _resultText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Text('Result: $_resultText\n')),
      ),
    );
  }
}
