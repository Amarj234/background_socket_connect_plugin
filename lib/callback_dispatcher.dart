

import 'background_socket_connect.dart' as background_socket;

/// Background entry point
@pragma('vm:entry-point')
void callbackDispatcher() {
  background_socket.callbackDispatcher();
}