import 'dart:async';

import 'package:dio/dio.dart';

import '../model/app_exception.dart';
import 'token_store.dart';

final class TokenRefresher {
  TokenRefresher({required this.dio, required this.tokenStore});

  final Dio dio;
  final InMemoryTokenStore tokenStore;

  Future<String>? _refreshing;

  Future<String> refresh() {
    final ongoing = _refreshing;
    if (ongoing != null) return ongoing;
    final completer = Completer<String>();
    _refreshing = completer.future;

    () async {
      try {
        final refreshToken = tokenStore.refreshToken;
        if (refreshToken == null) {
          throw const UnauthorizedAppException(message: '缺少 refreshToken');
        }

        final response = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: <String, Object?>{'refreshToken': refreshToken},
          options: Options(extra: <String, Object?>{'skipAuth': true}),
        );

        final data = response.data ?? const <String, dynamic>{};
        final inner =
            (data['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final newPair = TokenPair.fromJson(inner);
        await tokenStore.save(newPair);
        completer.complete(newPair.accessToken);
      } catch (e) {
        await tokenStore.clear();
        if (e is AppException) {
          completer.completeError(e);
        } else if (e is DioException) {
          completer.completeError(AppException.fromDioException(e));
        } else {
          completer.completeError(
            const UnauthorizedAppException(message: 'Token 刷新失败'),
          );
        }
      } finally {
        _refreshing = null;
      }
    }();

    return completer.future;
  }
}

