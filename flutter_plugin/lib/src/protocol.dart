import 'dart:convert';
import 'dart:math';

enum PluginErrorCode {
  ok(0),
  badArgs(1),
  notSupported(2),
  permissionDenied(3),
  permissionPermanentlyDenied(4),
  internalError(5);

  const PluginErrorCode(this.code);

  final int code;

  static PluginErrorCode fromCode(int? value) {
    return PluginErrorCode.values.firstWhere(
      (e) => e.code == value,
      orElse: () => PluginErrorCode.internalError,
    );
  }
}

class PluginException implements Exception {
  PluginException({
    required this.code,
    required this.message,
    this.requestId,
    this.details,
  });

  final PluginErrorCode code;
  final String message;
  final String? requestId;
  final Object? details;

  @override
  String toString() {
    return 'PluginException(code=${code.code}, message=$message, requestId=$requestId, details=$details)';
  }
}

class Result<T> {
  Result({
    required this.code,
    required this.message,
    required this.requestId,
    this.data,
  });

  final PluginErrorCode code;
  final String message;
  final String requestId;
  final T? data;

  bool get isOk => code == PluginErrorCode.ok;

  PluginException asException() {
    return PluginException(code: code, message: message, requestId: requestId);
  }

  static Result<T> fromMap<T>(
    Map<Object?, Object?> map, {
    T Function(Object? raw)? dataParser,
  }) {
    final requestId = (map['requestId'] ?? '').toString();
    final codeInt = map['code'];
    final code = PluginErrorCode.fromCode(codeInt is int ? codeInt : int.tryParse(codeInt?.toString() ?? ''));
    final message = (map['message'] ?? '').toString();
    final rawData = map['data'];
    final data = dataParser != null ? dataParser(rawData) : rawData as T?;
    return Result<T>(code: code, message: message, requestId: requestId, data: data);
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'code': code.code,
      'message': message,
      'requestId': requestId,
      'data': data,
    };
  }
}

class PluginRequest {
  PluginRequest({
    required this.type,
    required this.payload,
    required this.requestId,
    required this.version,
  });

  final int version;
  final String requestId;
  final String type;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'version': version,
      'requestId': requestId,
      'type': type,
      'payload': payload,
    };
  }

  String toJsonString() => jsonEncode(toMap());
}

class RequestId {
  static final Random _rand = Random();
  static int _counter = 0;

  static String create(String type) {
    _counter = (_counter + 1) & 0x7fffffff;
    final now = DateTime.now().microsecondsSinceEpoch;
    final salt = _rand.nextInt(1 << 20);
    return '$type-$now-$_counter-$salt';
  }
}

