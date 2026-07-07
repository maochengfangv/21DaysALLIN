import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_plugin/flutter_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(FlutterPluginChannelNames.method);

  setUp(() {
    channel.setMockMethodCallHandler((call) async {
      final request = (call.arguments as Map).cast<String, Object?>();
      return <String, Object?>{
        'code': 0,
        'message': 'ok',
        'data': 'mock',
        'requestId': request['requestId'] ?? '',
      };
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion returns Result', () async {
    final api = FlutterPluginApi();
    final result = await api.getPlatformVersion();
    expect(result.isOk, true);
    expect(result.data, 'mock');
  });
}
