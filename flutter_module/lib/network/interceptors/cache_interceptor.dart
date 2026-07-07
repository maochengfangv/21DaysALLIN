import 'dart:convert';

import 'package:dio/dio.dart';

final class CacheOptions {
  const CacheOptions({
    this.ttl = const Duration(seconds: 10),
    this.cacheKey,
    this.forceRefresh = false,
  });

  final Duration ttl;
  final String? cacheKey;
  final bool forceRefresh;
}

final class _CacheEntry {
  _CacheEntry({required this.raw, required this.expireAt});

  final String raw;
  final DateTime expireAt;
}

final class InMemoryCacheStore {
  final Map<String, _CacheEntry> _map = <String, _CacheEntry>{};

  _CacheEntry? get(String key) {
    final entry = _map[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expireAt)) {
      _map.remove(key);
      return null;
    }
    return entry;
  }

  void set(String key, String raw, Duration ttl) {
    _map[key] = _CacheEntry(raw: raw, expireAt: DateTime.now().add(ttl));
  }

  void clear() => _map.clear();
}

final class CacheInterceptor extends Interceptor {
  CacheInterceptor({required InMemoryCacheStore store}) : _store = store;

  final InMemoryCacheStore _store;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') {
      handler.next(options);
      return;
    }

    final cacheOptions = options.extra['cacheOptions'];
    if (cacheOptions is! CacheOptions) {
      handler.next(options);
      return;
    }
    if (cacheOptions.forceRefresh) {
      handler.next(options);
      return;
    }

    final key = cacheOptions.cacheKey ?? _defaultKey(options);
    final entry = _store.get(key);
    if (entry == null) {
      handler.next(options);
      return;
    }

    options.extra['cacheHit'] = true;
    final data = jsonDecode(entry.raw);
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ),
    );
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (options.method.toUpperCase() != 'GET') {
      handler.next(response);
      return;
    }

    final cacheOptions = options.extra['cacheOptions'];
    if (cacheOptions is! CacheOptions) {
      handler.next(response);
      return;
    }

    if (options.extra['cacheHit'] == true) {
      handler.next(response);
      return;
    }

    try {
      final raw = jsonEncode(response.data);
      final key = cacheOptions.cacheKey ?? _defaultKey(options);
      _store.set(key, raw, cacheOptions.ttl);
    } catch (_) {}

    handler.next(response);
  }

  String _defaultKey(RequestOptions options) {
    final qp = options.queryParameters;
    final sortedKeys = qp.keys.toList()..sort();
    final normalized = <String, Object?>{};
    for (final k in sortedKeys) {
      normalized[k] = qp[k];
    }
    return '${options.method}:${options.baseUrl}${options.path}?${jsonEncode(normalized)}';
  }
}

