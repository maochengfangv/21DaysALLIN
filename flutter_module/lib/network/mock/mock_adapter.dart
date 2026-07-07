import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';

final class MockAdapter implements HttpClientAdapter {
  MockAdapter({required InMemoryTokenStore tokenStore}) : _tokenStore = tokenStore;

  final InMemoryTokenStore _tokenStore;
  final Map<String, int> _counters = <String, int>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method}:${options.baseUrl}${options.path}';
    final count = (_counters[key] ?? 0) + 1;
    _counters[key] = count;

    if (options.path == '/timeout') {
      if (count <= 2) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'mock timeout',
        );
      }
      return _jsonOk(
        options,
        <String, Object?>{
          'scenario': 'timeout then success',
          'attempt': count,
          'ts': DateTime.now().toIso8601String(),
        },
      );
    }

    if (options.path == '/server_error') {
      return _json(
        statusCode: 500,
        body: <String, Object?>{
          'code': 50000,
          'message': 'mock 500',
          'data': null,
        },
      );
    }

    if (options.path == '/biz_fail') {
      return _json(
        statusCode: 200,
        body: <String, Object?>{
          'code': 1001,
          'message': 'mock biz fail',
          'data': null,
        },
      );
    }

    if (options.path == '/auth/refresh') {
      final refreshToken = _extractRefreshToken(options.data);
      if (refreshToken != 'refresh_ok') {
        return _json(
          statusCode: 401,
          body: <String, Object?>{
            'code': 40101,
            'message': 'refresh token invalid',
            'data': null,
          },
        );
      }
      final newAccessToken = 'token_${DateTime.now().millisecondsSinceEpoch}';
      final newPair =
          TokenPair(accessToken: newAccessToken, refreshToken: 'refresh_ok');
      await _tokenStore.save(newPair);
      return _json(
        statusCode: 200,
        body: <String, Object?>{
          'code': 0,
          'message': 'ok',
          'data': newPair.toJson(),
        },
      );
    }

    if (options.path == '/need_auth') {
      final auth = options.headers['Authorization']?.toString();
      if (auth == null || !auth.startsWith('Bearer ')) {
        return _json(
          statusCode: 401,
          body: <String, Object?>{
            'code': 40101,
            'message': 'missing token',
            'data': null,
          },
        );
      }
      final token = auth.substring('Bearer '.length);
      if (token == 'expired') {
        return _json(
          statusCode: 401,
          body: <String, Object?>{
            'code': 40101,
            'message': 'token expired',
            'data': null,
          },
        );
      }
      return _jsonOk(
        options,
        <String, Object?>{
          'scenario': 'authorized',
          'token': token,
          'ts': DateTime.now().toIso8601String(),
        },
      );
    }

    if (options.path == '/cached') {
      return _jsonOk(
        options,
        <String, Object?>{
          'scenario': 'cached',
          'serverTs': DateTime.now().toIso8601String(),
        },
      );
    }

    if (options.path == '/domain/info') {
      return _jsonOk(
        options,
        <String, Object?>{
          'scenario': 'multi-domain',
          'baseUrl': options.baseUrl,
          'path': options.path,
          'ts': DateTime.now().toIso8601String(),
        },
      );
    }

    return _jsonOk(
      options,
      <String, Object?>{
        'scenario': 'success',
        'baseUrl': options.baseUrl,
        'path': options.path,
        'query': options.queryParameters,
        'ts': DateTime.now().toIso8601String(),
      },
    );
  }

  String? _extractRefreshToken(Object? data) {
    if (data is Map) {
      return data['refreshToken']?.toString();
    }
    return null;
  }

  ResponseBody _jsonOk(RequestOptions options, Map<String, Object?> data) {
    return _json(
      statusCode: 200,
      body: <String, Object?>{'code': 0, 'message': 'ok', 'data': data},
    );
  }

  ResponseBody _json({
    required int statusCode,
    required Map<String, Object?> body,
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

