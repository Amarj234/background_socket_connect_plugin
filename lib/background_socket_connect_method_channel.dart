import 'dart:async';
import 'package:flutter/services.dart';
import 'background_socket_connect_platform_interface.dart';

class MethodChannelBackgroundSocketConnect extends BackgroundSocketConnectPlatform {
  final MethodChannel _methodChannel = const MethodChannel('background_socket_connect');

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
        final String message = call.arguments['message'];
        _onMessage?.call(message);
        break;
      case 'onDisconnected':
        final int code = call.arguments['code'];
        final String reason = call.arguments['reason'];
        _onDisconnected?.call(code, reason);
        break;
      case 'onError':
        final String error = call.arguments['error'];
        _onError?.call(error);
        break;
    }
  }

  @override
  Future<bool> connect({required String url, Map<String, String>? headers}) async {
    try {
      final result = await _methodChannel.invokeMethod('connect', {
        'url': url,
        'headers': headers ?? {},
      });
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to connect: ${e.message}');
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final result = await _methodChannel.invokeMethod('disconnect');
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to disconnect: ${e.message}');
    }
  }

  @override
  Future<bool> sendMessage(String message) async {
    try {
      final result = await _methodChannel.invokeMethod('sendMessage', {
        'message': message,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to send message: ${e.message}');
    }
  }

  @override
  Future<bool> startBackgroundService() async {
    try {
      final result = await _methodChannel.invokeMethod('startBackgroundService');
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to start background service: ${e.message}');
    }
  }

  @override
  Future<bool> stopBackgroundService() async {
    try {
      final result = await _methodChannel.invokeMethod('stopBackgroundService');
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop background service: ${e.message}');
    }
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



  @override
  Future<bool> getConnectionStatus() async {
    try {
      final result = await _methodChannel.invokeMethod('getConnectionStatus');
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to get connection status: ${e.message}');
    }
  }

  @override
  Future<bool> setBackgroundMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod('setBackgroundMode', {
        'enabled': enabled,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('Failed to set background mode: ${e.message}');
    }
  }
}