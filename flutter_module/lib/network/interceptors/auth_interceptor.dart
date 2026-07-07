import 'package:dio/dio.dart';

import '../auth/token_refresher.dart';
import '../auth/token_store.dart';
import '../model/app_exception.dart';

final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required InMemoryTokenStore tokenStore,
    required TokenRefresher tokenRefresher,
  })  : _dio = dio,
        _tokenStore = tokenStore,
        _tokenRefresher = tokenRefresher;

  final Dio _dio;
  final InMemoryTokenStore _tokenStore;
  final TokenRefresher _tokenRefresher;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    final token = _tokenStore.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.requestOptions.extra['skipAuth'] == true) {
      handler.next(err);
      return;
    }

    if (!_shouldRefresh(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    if (options.extra['__authRetried'] == true) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _tokenRefresher.refresh();
      final newOptions = options.copyWith();
      newOptions.extra = Map<String, dynamic>.from(options.extra);
      newOptions.extra['__authRetried'] = true;
      newOptions.headers = Map<String, dynamic>.from(options.headers);
      newOptions.headers['Authorization'] = 'Bearer $newToken';

      final response = await _dio.fetch<dynamic>(newOptions);
      handler.resolve(response);
    } catch (e) {
      if (e is AppException) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            message: e.message,
            type: DioExceptionType.unknown,
          ),
        );
      } else {
        handler.next(err);
      }
    }
  }

  bool _shouldRefresh(DioException err) {
    final status = err.response?.statusCode;
    if (status == 401) return true;
    return false;
  }
}

