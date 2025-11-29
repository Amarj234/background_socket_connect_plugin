import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:background_socket_connect/src/connection_model.dart';

class BackgroundSocketConnect {
  static const MethodChannel _channel =
  MethodChannel('background_socket_connect');

  static const EventChannel _messageChannel =
  EventChannel('background_socket_connect/messages');

  static const EventChannel _stateChannel =
  EventChannel('background_socket_connect/state');

  static Stream<SocketMessage>? _messageStream;
  static Stream<ConnectionState>? _stateStream;

  static const String _isolatePortName = "background_socket_port";

  /// Initialize background socket service
  static Future<bool> initializeService({
    required SocketConfig config,
    required Function(SocketMessage) onMessage,
  }) async {
    // Register callback port
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, _isolatePortName);

    // Listen messages from background isolate
    port.listen((data) {
      if (data is SocketMessage) {
        onMessage(data);
      }
    });

    final callbackHandle =
    PluginUtilities.getCallbackHandle(callbackDispatcher);

    if (callbackHandle == null) {
      throw Exception("Callback handle retrieval failed");
    }

    final result = await _channel.invokeMethod('initializeService', {
      'config': config.toMap(),
      'callbackHandle': callbackHandle.toRawHandle(),
    });

    return result == true;
  }

  static Future<bool> connect() async =>
      (await _channel.invokeMethod('connect')) == true;

  static Future<bool> disconnect() async =>
      (await _channel.invokeMethod('disconnect')) == true;

  static Future<bool> sendMessage(String message) async =>
      (await _channel.invokeMethod('sendMessage', {'message': message})) == true;

  static Future<ConnectionState> getConnectionState() async {
    final result = await _channel.invokeMethod('getConnectionState');
    return ConnectionState.fromMap(Map<String, dynamic>.from(result));
  }

  /// Stream broadcast from native foreground
  static Stream<SocketMessage> get onMessage =>
      _messageStream ??= _messageChannel
          .receiveBroadcastStream()
          .map((event) => SocketMessage.fromMap(Map<String, dynamic>.from(event)));

  static Stream<ConnectionState> get onStateChange =>
      _stateStream ??= _stateChannel.receiveBroadcastStream().map(
            (event) =>
            ConnectionState.fromMap(Map<String, dynamic>.from(event)),
      );

  static Future<bool> isConnected() async =>
      (await _channel.invokeMethod('isConnected')) == true;
}

/// Background isolate entry (DO NOT REMOVE pragma)
@pragma('vm:entry-point')
void callbackDispatcher() {
  const MethodChannel background =
  MethodChannel('background_socket_connect_background');

  // Get main isolate port
  final SendPort? sendPort =
  IsolateNameServer.lookupPortByName("background_socket_port");

  background.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onSocketMessage':
        final data = SocketMessage.fromMap(Map<String, dynamic>.from(call.arguments));
        sendPort?.send(data);
        break;

      case 'onSocketStateChange':
      // You may handle this too if needed
        break;
    }
    return true;
  });
}
