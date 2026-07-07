import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({
    required bool Function() enabled,
    required this.ua,
    required this.appVersion,
  }) : _enabled = enabled;

  final bool Function() _enabled;
  final String ua;
  final String appVersion;

  static int _seq = 0;
  static final Random _rand = Random();

  String _nextRequestId() {
    _seq = (_seq + 1) % 1000000;
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = _rand.nextInt(1000000);
    return '$ts-$_seq-$r';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['ua'] = ua;
    options.headers['appVersion'] = appVersion;
    options.headers.putIfAbsent('requestId', _nextRequestId);
    options.extra['requestId'] = options.headers['requestId']?.toString();

    final timeoutMs = (options.extra['timeoutMs'] as num?)?.toInt();
    if (timeoutMs != null && timeoutMs > 0) {
      final d = Duration(milliseconds: timeoutMs);
      options.connectTimeout = d;
      options.sendTimeout = d;
      options.receiveTimeout = d;
    }

    if (_enabled()) {
      debugPrint(
        '[DIO][REQ] ${options.method} ${options.baseUrl}${options.path} '
        'rid=${options.extra['requestId']} '
        'q=${options.queryParameters} '
        'data=${options.data}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_enabled()) {
      debugPrint(
        '[DIO][RES] ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.baseUrl}${response.requestOptions.path} '
        'rid=${response.requestOptions.extra['requestId']} '
        'extra=${response.requestOptions.extra} '
        'data=${response.data}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_enabled()) {
      debugPrint(
        '[DIO][ERR] ${err.type} ${err.response?.statusCode} '
        '${err.requestOptions.method} '
        '${err.requestOptions.baseUrl}${err.requestOptions.path} '
        'rid=${err.requestOptions.extra['requestId']} '
        'extra=${err.requestOptions.extra} '
        'msg=${err.message}',
      );
    }
    handler.next(err);
  }
}
