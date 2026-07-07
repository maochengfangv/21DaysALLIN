import 'dart:async';

import 'package:dio/dio.dart';

final class RetryOptions {
  const RetryOptions({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 2),
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
}

final class RetryInterceptor extends Interceptor {
  RetryInterceptor({required Dio dio, required RetryOptions defaultOptions})
      : _dio = dio,
        _defaultOptions = defaultOptions;

  final Dio _dio;
  final RetryOptions _defaultOptions;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (options.extra['skipRetry'] == true) {
      handler.next(err);
      return;
    }

    final retryOptions =
        (options.extra['retryOptions'] as RetryOptions?) ?? _defaultOptions;
    final method = options.method.toUpperCase();
    final isIdempotent = _isIdempotent(method) || options.extra['retryable'] == true;
    if (!isIdempotent) {
      handler.next(err);
      return;
    }

    final retryCount = (options.extra['retryCount'] as num?)?.toInt() ?? 0;
    if (retryCount >= retryOptions.maxAttempts) {
      handler.next(err);
      return;
    }

    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    options.extra['retryCount'] = retryCount + 1;
    final delay = _backoff(retryCount, retryOptions);
    await Future<void>.delayed(delay);

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }

  bool _isIdempotent(String method) {
    return method == 'GET' ||
        method == 'HEAD' ||
        method == 'PUT' ||
        method == 'DELETE' ||
        method == 'OPTIONS';
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final status = err.response?.statusCode;
    if (status != null && status >= 500) return true;
    return false;
  }

  Duration _backoff(int retryCount, RetryOptions options) {
    final factor = 1 << retryCount;
    final ms = options.baseDelay.inMilliseconds * factor;
    final bounded = ms > options.maxDelay.inMilliseconds
        ? options.maxDelay.inMilliseconds
        : ms;
    return Duration(milliseconds: bounded);
  }
}

