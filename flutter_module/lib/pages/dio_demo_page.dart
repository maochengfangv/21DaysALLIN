import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/auth/token_store.dart';
import '../network/dio_factory.dart';
import '../network/interceptors/cache_interceptor.dart';
import '../network/interceptors/retry_interceptor.dart';
import '../network/model/app_exception.dart';
import '../network/network_client.dart';

final class DioDemoPage extends StatefulWidget {
  const DioDemoPage({super.key, required this.navStyle});

  final String navStyle;

  @override
  State<DioDemoPage> createState() => _DioDemoPageState();
}

final class _DioDemoPageState extends State<DioDemoPage> {
  final NetworkClient _client = NetworkClient.instance;
  String _title = 'Idle';
  String _output = 'Tap a button to run a mocked request.';
  bool _isError = false;
  int _elapsedMs = 0;
  Map<String, Object?> _meta = const <String, Object?>{};

  Future<void> _run(
    String title,
    Future<void> Function() task,
  ) async {
    setState(() {
      _title = title;
      _isError = false;
      _elapsedMs = 0;
      _meta = const <String, Object?>{};
      _output = '';
    });
    final sw = Stopwatch()..start();
    try {
      await task();
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      final ex = e is AppException ? e : null;
      setState(() {
        _isError = true;
        _elapsedMs = sw.elapsedMilliseconds;
        _meta = <String, Object?>{
          'type': ex?.type.name ?? 'unknown',
          'code': ex?.code,
          'statusCode': ex?.statusCode,
          'requestId': ex?.requestId,
          'baseUrl': ex?.baseUrl,
          'retryCount': ex?.retryCount ?? 0,
          'cacheHit': ex?.cacheHit ?? false,
        };
        _output = ex?.message ?? e.toString();
      });
      return;
    }
    sw.stop();
    if (!mounted) return;
    setState(() {
      _elapsedMs = sw.elapsedMilliseconds;
    });
  }

  String _pretty(Object? obj) {
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj?.toString() ?? 'null';
    }
  }

  Future<void> _doSuccess() {
    return _run('GET success', () async {
      final res = await _client.get('/success');
      setState(() {
        _meta = res.meta.toJson();
        _output = _pretty(res.data);
      });
    });
  }

  Future<void> _doCached() {
    return _run('GET cached (2 calls)', () async {
      final ttl = const Duration(seconds: 60);
      final first = await _client.get(
        '/cached',
        cacheOptions: CacheOptions(ttl: ttl, forceRefresh: true),
      );
      final second = await _client.get('/cached', cacheOptions: CacheOptions(ttl: ttl));
      setState(() {
        _meta = <String, Object?>{
          'first': first.meta.toJson(),
          'second': second.meta.toJson(),
        };
        _output = _pretty(<String, Object?>{
          'firstData': first.data,
          'secondData': second.data,
        });
      });
    });
  }

  Future<void> _doAuthRefresh() {
    return _run('401 then refresh', () async {
      final res = await _client.get('/need_auth');
      setState(() {
        _meta = res.meta.toJson();
        _output = _pretty(res.data);
      });
    });
  }

  Future<void> _doTimeoutRetry() {
    return _run('timeout retry', () async {
      final res = await _client.get(
        '/timeout',
        retryOptions: const RetryOptions(maxAttempts: 3),
      );
      setState(() {
        _meta = res.meta.toJson();
        _output = _pretty(res.data);
      });
    });
  }

  Future<void> _doServerError() {
    return _run('server error', () async {
      final res = await _client.get(
        '/server_error',
        retryOptions: const RetryOptions(maxAttempts: 3),
      );
      setState(() {
        _meta = res.meta.toJson();
        _output = _pretty(res.data);
      });
    });
  }

  Future<void> _doMultiDomain() {
    return _run('multi domain', () async {
      final results = await Future.wait<NetworkResult<dynamic>>([
        _client.get('/domain/info', domain: ApiDomain.apiA, loadingKey: 'multi'),
        _client.get('/domain/info', domain: ApiDomain.apiB, loadingKey: 'multi'),
      ]);
      setState(() {
        _meta = <String, Object?>{
          'apiA': results[0].meta.toJson(),
          'apiB': results[1].meta.toJson(),
        };
        _output = _pretty(<String, Object?>{
          'apiA': results[0].data,
          'apiB': results[1].data,
        });
      });
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dio Demo'),
        actions: [
          IconButton(onPressed: _copy, icon: const Icon(Icons.copy)),
          Switch(
            value: _client.logEnabled,
            onChanged: (v) {
              setState(() => _client.setLogEnabled(v));
            },
          ),
          IconButton(
            onPressed: () async {
              await const MethodChannel('com.example.hybrid/router').invokeMethod(
                'closeFlutter',
                const <String, Object?>{
                  'version': 1,
                  'result': <String, Object?>{'message': 'closed from dio demo'},
                },
              );
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<TokenPair?>(
            valueListenable: InMemoryTokenStore.instance.listenable,
            builder: (context, tokens, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('navStyle: ${widget.navStyle}'),
                      const SizedBox(height: 4),
                      Text('accessToken: ${tokens?.accessToken ?? '(null)'}'),
                      Text('refreshToken: ${tokens?.refreshToken ?? '(null)'}'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: _doSuccess, child: const Text('GET success')),
              FilledButton(onPressed: _doCached, child: const Text('GET cached')),
              FilledButton(
                onPressed: _doAuthRefresh,
                child: const Text('401 then refresh'),
              ),
              FilledButton(
                onPressed: _doTimeoutRetry,
                child: const Text('timeout retry'),
              ),
              FilledButton(
                onPressed: _doServerError,
                child: const Text('server error'),
              ),
              FilledButton(
                onPressed: _doMultiDomain,
                child: const Text('multi domain'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('elapsed: ${_elapsedMs}ms'),
                  const SizedBox(height: 8),
                  Text('meta: ${_pretty(_meta)}'),
                  const SizedBox(height: 8),
                  SelectableText(
                    _output.isEmpty ? '(empty)' : _output,
                    style: TextStyle(
                      color: _isError ? Colors.red : null,
                      fontFamily: 'Menlo',
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

