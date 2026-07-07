final class ApiResponse<T> {
  const ApiResponse({required this.code, required this.message, this.data});

  final int code;
  final String message;
  final T? data;

  bool get isSuccess => code == 0;

  static ApiResponse<dynamic> fromJson(Map<String, dynamic> json) {
    return ApiResponse<dynamic>(
      code: (json['code'] as num?)?.toInt() ?? -1,
      message: json['message']?.toString() ?? '',
      data: json['data'],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'code': code, 'message': message, 'data': data};
  }
}

