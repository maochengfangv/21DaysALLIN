import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'channel_names.dart';
import 'protocol.dart';

class FlutterPluginApi {
  FlutterPluginApi()
    : _method = const MethodChannel(
        FlutterPluginChannelNames.method,
        StandardMethodCodec(),
      ),
      _events = const EventChannel(
        FlutterPluginChannelNames.events,
        StandardMethodCodec(),
      ),
      _messageString = const BasicMessageChannel<String>(
        FlutterPluginChannelNames.messageString,
        StringCodec(),
      ),
      _messageStandard = const BasicMessageChannel<Object?>(
        FlutterPluginChannelNames.messageStandard,
        StandardMessageCodec(),
      );

  static const int apiVersion = 1;

  final MethodChannel _method;
  final EventChannel _events;
  final BasicMessageChannel<String> _messageString;
  final BasicMessageChannel<Object?> _messageStandard;

  Stream<Map<String, Object?>> get eventStream => _events
      .receiveBroadcastStream()
      .map<Map<String, Object?>>((dynamic e) => (e as Map).cast<String, Object?>());

  Future<Result<String>> getPlatformVersion() async {
    return _invoke<String>(
      method: 'getPlatformVersion',
      payload: const <String, Object?>{},
      dataParser: (raw) => raw?.toString() ?? '',
    );
  }

  Future<Result<Map<String, Object?>>> getDeviceInfo() async {
    return _invoke<Map<String, Object?>>(
      method: 'getDeviceInfo',
      payload: const <String, Object?>{},
      dataParser: (raw) => (raw as Map).cast<String, Object?>(),
    );
  }

  Future<Result<Map<String, Object?>>> requestCameraPermission() async {
    return _invoke<Map<String, Object?>>(
      method: 'requestCameraPermission',
      payload: const <String, Object?>{},
      dataParser: (raw) => (raw as Map).cast<String, Object?>(),
    );
  }

  Future<Result<void>> startTicking({required int intervalMs}) async {
    return _invoke<void>(
      method: 'startTicking',
      payload: <String, Object?>{'intervalMs': intervalMs},
    );
  }

  Future<Result<void>> stopTicking() async {
    return _invoke<void>(
      method: 'stopTicking',
      payload: const <String, Object?>{},
    );
  }

  Future<Result<String>> sendStringMessage({required String text}) async {
    final requestId = RequestId.create('message_string');
    final request = PluginRequest(
      version: apiVersion,
      requestId: requestId,
      type: 'echoString',
      payload: <String, Object?>{'text': text},
    );

    final raw = await _messageString.send(request.toJsonString());
    if (raw == null || raw.isEmpty) {
      return Result<String>(
        code: PluginErrorCode.internalError,
        message: 'Empty response',
        requestId: requestId,
        data: null,
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return Result<String>(
        code: PluginErrorCode.internalError,
        message: 'Invalid response',
        requestId: requestId,
        data: null,
      );
    }

    return Result.fromMap<String>(
      decoded.cast<Object?, Object?>(),
      dataParser: (value) => value?.toString() ?? '',
    );
  }

  Future<Result<Map<String, Object?>>> sendStandardMessage({
    required Map<String, Object?> payload,
  }) async {
    final requestId = RequestId.create('message_standard');
    final request = PluginRequest(
      version: apiVersion,
      requestId: requestId,
      type: 'echoStandard',
      payload: payload,
    );
    final raw = await _messageStandard.send(request.toMap());
    if (raw is! Map) {
      return Result<Map<String, Object?>>(
        code: PluginErrorCode.internalError,
        message: 'Invalid response',
        requestId: requestId,
      );
    }

    return Result.fromMap<Map<String, Object?>>(
      raw.cast<Object?, Object?>(),
      dataParser: (value) => (value as Map).cast<String, Object?>(),
    );
  }

  Future<Result<T>> _invoke<T>({
    required String method,
    required Map<String, Object?> payload,
    T Function(Object? raw)? dataParser,
  }) async {
    final requestId = RequestId.create(method);
    final request = PluginRequest(
      version: apiVersion,
      requestId: requestId,
      type: method,
      payload: payload,
    );

    try {
      final raw = await _method.invokeMethod<Object?>(method, request.toMap());
      if (raw is! Map) {
        return Result<T>(
          code: PluginErrorCode.internalError,
          message: 'Invalid response',
          requestId: requestId,
        );
      }
      return Result.fromMap<T>(raw.cast<Object?, Object?>(), dataParser: dataParser);
    } on PlatformException catch (e) {
      return Result<T>(
        code: PluginErrorCode.internalError,
        message: e.message ?? 'PlatformException',
        requestId: requestId,
      );
    } catch (e) {
      return Result<T>(
        code: PluginErrorCode.internalError,
        message: e.toString(),
        requestId: requestId,
      );
    }
  }
}
