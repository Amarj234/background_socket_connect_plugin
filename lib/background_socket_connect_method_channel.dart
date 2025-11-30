import 'dart:async';
import 'package:flutter/services.dart';
import 'background_socket_connect_platform_interface.dart';

class MethodChannelBackgroundSocketConnect extends BackgroundSocketConnectPlatform {
  final MethodChannel _methodChannel =
  const MethodChannel('background_socket_connect');

  Function()? _onConnected;
  Function(String)? _onMessage;
  Function(int, String)? _onDisconnected;
  Function(String)? _onError;

  MethodChannelBackgroundSocketConnect() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnected':
        _onConnected?.call();
        break;

      case 'onMessage':
        final String message = call.arguments?['message'] ?? "";
        _onMessage?.call(message);
        break;

      case 'onDisconnected':
        final int code = call.arguments?['code'] ?? -1;
        final String reason = call.arguments?['reason'] ?? "";
        _onDisconnected?.call(code, reason);
        break;

      case 'onError':
        final String error = call.arguments?['error'] ?? "Unknown error";
        _onError?.call(error);
        break;
    }
  }

  @override
  Future<bool> connect({required String url, Map<String, String>? headers}) async {
    final result = await _methodChannel.invokeMethod('connect', {
      'url': url,
      'headers': headers ?? {},
    });
    return result == true;
  }

  @override
  Future<bool> disconnect() async {
    final result = await _methodChannel.invokeMethod('disconnect');
    return result == true;
  }

  @override
  Future<bool> sendMessage(String message) async {
    final result = await _methodChannel.invokeMethod('sendMessage', {
      'message': message,
    });
    return result == true;
  }

  @override
  Future<bool> startBackgroundService() async {
    final result =
    await _methodChannel.invokeMethod('startBackgroundService');
    return result == true;
  }

  @override
  Future<bool> stopBackgroundService() async {
    final result =
    await _methodChannel.invokeMethod('stopBackgroundService');
    return result == true;
  }

  @override
  Future<bool> getConnectionStatus() async {
    final result = await _methodChannel.invokeMethod('getConnectionStatus');
    return result == true;
  }

  @override
  Future<bool> setBackgroundMode(bool enabled) async {
    final result = await _methodChannel.invokeMethod('setBackgroundMode', {
      'enabled': enabled,
    });
    return result == true;
  }

  @override
  void setOnConnectedCallback(Function() callback) {
    _onConnected = callback;
  }

  @override
  void setOnMessageCallback(Function(String message) callback) {
    _onMessage = callback;
  }

  @override
  void setOnDisconnectedCallback(Function(int code, String reason) callback) {
    _onDisconnected = callback;
  }

  @override
  void setOnErrorCallback(Function(String error) callback) {
    _onError = callback;
  }
}
