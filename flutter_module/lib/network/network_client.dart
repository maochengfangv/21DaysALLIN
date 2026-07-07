import 'package:dio/dio.dart';

import '../env/app_env.dart';
import '../ui/loading/loading_controller.dart';
import 'auth/token_refresher.dart';
import 'auth/token_store.dart';
import 'dio_factory.dart';
import 'domain.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'mock/mock_adapter.dart';
import 'model/app_exception.dart';

final class NetworkMeta {
  const NetworkMeta({
    required this.requestId,
    required this.baseUrl,
    required this.cacheHit,
    required this.retryCount,
    required this.domain,
  });

  final String? requestId;
  final String baseUrl;
  final bool cacheHit;
  final int retryCount;
  final String domain;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'baseUrl': baseUrl,
      'domain': domain,
      'cacheHit': cacheHit,
      'retryCount': retryCount,
    };
  }
}

final class NetworkResult<T> {
  const NetworkResult({required this.data, required this.meta});

  final T data;
  final NetworkMeta meta;
}

final class NetworkClient {
  NetworkClient._() {
    final tokenStore = InMemoryTokenStore.instance;
    final mockAdapter = MockAdapter(tokenStore: tokenStore);
    final cacheStore = InMemoryCacheStore();
    final factory = DioFactory(tokenStore: tokenStore, mockAdapter: mockAdapter);
    final refreshDio = factory.createRefreshDio(logEnabled: () => _logEnabled);
    final refresher = TokenRefresher(dio: refreshDio, tokenStore: tokenStore);
    _tokenStore = tokenStore;
    _dio = factory.createMainDio(
      tokenRefresher: refresher,
      cacheStore: cacheStore,
      logEnabled: () => _logEnabled,
    );
  }

  static final NetworkClient instance = NetworkClient._();

  late final Dio _dio;
  late final InMemoryTokenStore _tokenStore;

  static bool _logEnabled = AppEnv.current.httpLogEnabled;

  bool get logEnabled => _logEnabled;

  void setLogEnabled(bool enabled) {
    _logEnabled = enabled;
  }

  InMemoryTokenStore get tokenStore => _tokenStore;

  Future<NetworkResult<dynamic>> get(
    String path, {
    ApiDomain domain = ApiDomain.apiA,
    Map<String, dynamic>? queryParameters,
    CacheOptions? cacheOptions,
    RetryOptions? retryOptions,
    bool autoLoading = true,
    String? loadingKey,
    int? timeoutMs,
  }) {
    return request<dynamic>(
      path,
      method: 'GET',
      domain: domain,
      queryParameters: queryParameters,
      cacheOptions: cacheOptions,
      retryOptions: retryOptions,
      autoLoading: autoLoading,
      loadingKey: loadingKey,
      timeoutMs: timeoutMs,
    );
  }

  Future<NetworkResult<dynamic>> post(
    String path, {
    ApiDomain domain = ApiDomain.apiA,
    Object? data,
    Map<String, dynamic>? queryParameters,
    RetryOptions? retryOptions,
    bool autoLoading = true,
    String? loadingKey,
    int? timeoutMs,
    bool retryable = false,
  }) {
    return request<dynamic>(
      path,
      method: 'POST',
      domain: domain,
      data: data,
      queryParameters: queryParameters,
      retryOptions: retryOptions,
      autoLoading: autoLoading,
      loadingKey: loadingKey,
      timeoutMs: timeoutMs,
      retryable: retryable,
    );
  }

  Future<NetworkResult<T>> request<T>(
    String path, {
    required String method,
    ApiDomain domain = ApiDomain.apiA,
    Object? data,
    Map<String, dynamic>? queryParameters,
    CacheOptions? cacheOptions,
    RetryOptions? retryOptions,
    bool autoLoading = true,
    String? loadingKey,
    int? timeoutMs,
    bool retryable = false,
  }) async {
    if (autoLoading) {
      LoadingController.instance.show(key: loadingKey);
    }

    try {
      final extra = <String, Object?>{
        'domain': domain,
        if (cacheOptions != null) 'cacheOptions': cacheOptions,
        if (retryOptions != null) 'retryOptions': retryOptions,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        if (retryable) 'retryable': true,
      };

      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, extra: extra),
      );

      final reqExtra = response.requestOptions.extra;
      final meta = NetworkMeta(
        requestId: reqExtra['requestId']?.toString(),
        baseUrl: response.requestOptions.baseUrl,
        cacheHit: reqExtra['cacheHit'] == true,
        retryCount: (reqExtra['retryCount'] as num?)?.toInt() ?? 0,
        domain: reqExtra['domain']?.toString() ?? ApiDomain.apiA.name,
      );
      return NetworkResult<T>(data: response.data as T, meta: meta);
    } on DioException catch (e) {
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      throw AppException.fromDioException(e);
    } finally {
      if (autoLoading) {
        LoadingController.instance.hide(key: loadingKey);
      }
    }
  }
}
