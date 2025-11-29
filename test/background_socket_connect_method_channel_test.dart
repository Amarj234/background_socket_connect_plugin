import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_socket_connect/background_socket_connect_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBackgroundSocketConnect platform = MethodChannelBackgroundSocketConnect();
  const MethodChannel channel = MethodChannel('background_socket_connect');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
