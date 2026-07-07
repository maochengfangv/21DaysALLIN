import 'package:dio/dio.dart';

enum AppExceptionType { network, timeout, unauthorized, server, biz, unknown }

sealed class AppException implements Exception {
  const AppException({
    required this.type,
    required this.message,
    this.code,
    this.statusCode,
    this.requestId,
    this.baseUrl,
    this.retryCount = 0,
    this.cacheHit = false,
  });

  final AppExceptionType type;
  final String message;
  final int? code;
  final int? statusCode;
  final String? requestId;
  final String? baseUrl;
  final int retryCount;
  final bool cacheHit;

  @override
  String toString() => 'AppException($type): $message';

  static AppException fromDioException(DioException error) {
    final extras = error.requestOptions.extra;
    final requestId = extras['requestId']?.toString();
    final baseUrl = error.requestOptions.baseUrl;
    final retryCount = (extras['retryCount'] as num?)?.toInt() ?? 0;
    final cacheHit = extras['cacheHit'] == true;
    final statusCode = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return TimeoutAppException(
        message: '请求超时',
        requestId: requestId,
        baseUrl: baseUrl,
        statusCode: statusCode,
        retryCount: retryCount,
        cacheHit: cacheHit,
      );
    }

    if (statusCode == 401) {
      return UnauthorizedAppException(
        message: '未授权，请重新登录',
        requestId: requestId,
        baseUrl: baseUrl,
        statusCode: statusCode,
        retryCount: retryCount,
        cacheHit: cacheHit,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerAppException(
        message: '服务器错误($statusCode)',
        requestId: requestId,
        baseUrl: baseUrl,
        statusCode: statusCode,
        retryCount: retryCount,
        cacheHit: cacheHit,
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return NetworkAppException(
        message: '网络异常',
        requestId: requestId,
        baseUrl: baseUrl,
        statusCode: statusCode,
        retryCount: retryCount,
        cacheHit: cacheHit,
      );
    }

    return UnknownAppException(
      message: error.message ?? '未知异常',
      requestId: requestId,
      baseUrl: baseUrl,
      statusCode: statusCode,
      retryCount: retryCount,
      cacheHit: cacheHit,
    );
  }
}

final class NetworkAppException extends AppException {
  const NetworkAppException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.network);
}

final class TimeoutAppException extends AppException {
  const TimeoutAppException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.timeout);
}

final class UnauthorizedAppException extends AppException {
  const UnauthorizedAppException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.unauthorized);
}

final class ServerAppException extends AppException {
  const ServerAppException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.server);
}

final class BizAppException extends AppException {
  const BizAppException({
    required super.message,
    required int super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.biz);
}

final class UnknownAppException extends AppException {
  const UnknownAppException({
    required super.message,
    super.code,
    super.statusCode,
    super.requestId,
    super.baseUrl,
    super.retryCount,
    super.cacheHit,
  }) : super(type: AppExceptionType.unknown);
}

