class SocketConfig {
  final String url;
  final Map<String, dynamic>? headers;
  final int reconnectInterval;
  final int heartbeatInterval;
  final int timeout;
  final List<String>? protocols;

  const SocketConfig({
    required this.url,
    this.headers,
    this.reconnectInterval = 5000,
    this.heartbeatInterval = 30000,
    this.timeout = 30000,
    this.protocols,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'headers': headers,
      'reconnectInterval': reconnectInterval,
      'heartbeatInterval': heartbeatInterval,
      'timeout': timeout,
      'protocols': protocols,
    };
  }

  static SocketConfig fromMap(Map<String, dynamic> map) {
    return SocketConfig(
      url: map['url'],
      headers: Map<String, dynamic>.from(map['headers'] ?? {}),
      reconnectInterval: map['reconnectInterval'],
      heartbeatInterval: map['heartbeatInterval'],
      timeout: map['timeout'],
      protocols: map['protocols'] != null ? List<String>.from(map['protocols']) : null,
    );
  }
}

class SocketMessage {
  final String type;
  final String? data;
  final DateTime timestamp;
  final String? error;

  SocketMessage({
    required this.type,
    this.data,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'error': error,
    };
  }

  static SocketMessage fromMap(Map<String, dynamic> map) {
    return SocketMessage(
      type: map['type'],
      data: map['data'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      error: map['error'],
    );
  }
}

class ConnectionState {
  final bool connected;
  final String? error;
  final DateTime lastActivity;

  ConnectionState({
    required this.connected,
    this.error,
    required this.lastActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'connected': connected,
      'error': error,
      'lastActivity': lastActivity.millisecondsSinceEpoch,
    };
  }

  static ConnectionState fromMap(Map<String, dynamic> map) {
    return ConnectionState(
      connected: map['connected'],
      error: map['error'],
      lastActivity: DateTime.fromMillisecondsSinceEpoch(map['lastActivity']),
    );
  }
}