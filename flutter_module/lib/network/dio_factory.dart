import 'package:dio/dio.dart';

import 'auth/token_refresher.dart';
import 'auth/token_store.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/unwrap_interceptor.dart';
import 'mock/mock_adapter.dart';

enum ApiDomain { apiA, apiB }

final class DioFactory {
  DioFactory({
    required InMemoryTokenStore tokenStore,
    required MockAdapter mockAdapter,
  })  : _tokenStore = tokenStore,
        _mockAdapter = mockAdapter;

  final InMemoryTokenStore _tokenStore;
  final MockAdapter _mockAdapter;

  final Map<ApiDomain, String> _baseUrls = <ApiDomain, String>{
    ApiDomain.apiA: 'https://api-a.mock',
    ApiDomain.apiB: 'https://api-b.mock',
  };

  Dio createMainDio({
    required TokenRefresher tokenRefresher,
    required InMemoryCacheStore cacheStore,
    required bool Function() logEnabled,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrls[ApiDomain.apiA]!,
        connectTimeout: const Duration(milliseconds: 800),
        sendTimeout: const Duration(milliseconds: 800),
        receiveTimeout: const Duration(milliseconds: 800),
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
    dio.httpClientAdapter = _mockAdapter;

    dio.interceptors.addAll([
      UnwrapInterceptor(),
      AuthInterceptor(dio: dio, tokenStore: _tokenStore, tokenRefresher: tokenRefresher),
      RetryInterceptor(dio: dio, defaultOptions: const RetryOptions()),
      CacheInterceptor(store: cacheStore),
      _BaseUrlInterceptor(baseUrls: _baseUrls),
      LoggingInterceptor(enabled: logEnabled, ua: 'flutter_module', appVersion: '1.0.0'),
    ]);

    return dio;
  }

  Dio createRefreshDio({required bool Function() logEnabled}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrls[ApiDomain.apiA]!,
        connectTimeout: const Duration(milliseconds: 800),
        sendTimeout: const Duration(milliseconds: 800),
        receiveTimeout: const Duration(milliseconds: 800),
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
    dio.httpClientAdapter = _mockAdapter;
    dio.interceptors.addAll([
      _BaseUrlInterceptor(baseUrls: _baseUrls),
      LoggingInterceptor(enabled: logEnabled, ua: 'flutter_module', appVersion: '1.0.0'),
    ]);
    return dio;
  }
}

final class _BaseUrlInterceptor extends Interceptor {
  _BaseUrlInterceptor({required Map<ApiDomain, String> baseUrls}) : _baseUrls = baseUrls;

  final Map<ApiDomain, String> _baseUrls;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final raw = options.extra['domain'];
    ApiDomain domain;
    if (raw is ApiDomain) {
      domain = raw;
    } else if (raw is String) {
      domain = ApiDomain.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => ApiDomain.apiA,
      );
    } else {
      domain = ApiDomain.apiA;
    }
    options.baseUrl = _baseUrls[domain] ?? options.baseUrl;
    options.extra['domain'] = domain.name;
    handler.next(options);
  }
}
