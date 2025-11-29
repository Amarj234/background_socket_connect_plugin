import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'background_socket_connect_method_channel.dart';

abstract class BackgroundSocketConnectPlatform extends PlatformInterface {
  BackgroundSocketConnectPlatform() : super(token: _token);

  static final Object _token = Object();

  static BackgroundSocketConnectPlatform _instance = MethodChannelBackgroundSocketConnect();

  static BackgroundSocketConnectPlatform get instance => _instance;

  static set instance(BackgroundSocketConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // Socket methods
  Future<bool> connect({required String url, Map<String, String>? headers});
  Future<bool> disconnect();
  Future<bool> sendMessage(String message);
  Future<bool> getConnectionStatus();

  // Background service methods
  Future<bool> setBackgroundMode(bool enabled);
  Future<bool> startBackgroundService();
  Future<bool> stopBackgroundService();

  // Event callbacks
  void setOnConnectedCallback(Function() callback);
  void setOnMessageCallback(Function(String message) callback);
  void setOnDisconnectedCallback(Function(int code, String reason) callback);
  void setOnErrorCallback(Function(String error) callback);
}