import 'package:dio/dio.dart';

import '../model/api_response.dart';
import '../model/app_exception.dart';

final class UnwrapInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final api = ApiResponse.fromJson(data);
      if (api.isSuccess) {
        response.data = api.data;
        handler.next(response);
        return;
      }
      throw BizAppException(
        code: api.code,
        message: api.message.isEmpty ? '业务错误(${api.code})' : api.message,
        requestId: response.requestOptions.extra['requestId']?.toString(),
        baseUrl: response.requestOptions.baseUrl,
        statusCode: response.statusCode,
        retryCount: (response.requestOptions.extra['retryCount'] as num?)?.toInt() ?? 0,
        cacheHit: response.requestOptions.extra['cacheHit'] == true,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err.error;
    if (error is AppException) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: error,
          message: error.message,
        ),
      );
      return;
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: AppException.fromDioException(err),
        message: err.message,
      ),
    );
  }
}
