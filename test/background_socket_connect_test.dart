import 'package:flutter_test/flutter_test.dart';
import 'package:background_socket_connect/background_socket_connect.dart';
import 'package:background_socket_connect/background_socket_connect_platform_interface.dart';
import 'package:background_socket_connect/background_socket_connect_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBackgroundSocketConnectPlatform
    with MockPlatformInterfaceMixin
    implements BackgroundSocketConnectPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BackgroundSocketConnectPlatform initialPlatform = BackgroundSocketConnectPlatform.instance;

  test('$MethodChannelBackgroundSocketConnect is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBackgroundSocketConnect>());
  });

  test('getPlatformVersion', () async {
    BackgroundSocketConnect backgroundSocketConnectPlugin = BackgroundSocketConnect();
    MockBackgroundSocketConnectPlatform fakePlatform = MockBackgroundSocketConnectPlatform();
    BackgroundSocketConnectPlatform.instance = fakePlatform;

    expect(await backgroundSocketConnectPlugin.getPlatformVersion(), '42');
  });
}
