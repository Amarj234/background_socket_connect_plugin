import 'package:background_socket_connect/background_socket_connect_platform_interface.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BackgroundSocketConnectPlatform _socket = BackgroundSocketConnectPlatform.instance;
  final TextEditingController _messageController = TextEditingController();
  List<String> messages = [];
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _setupSocketCallbacks();
  }

  void _setupSocketCallbacks() {
    _socket.setOnConnectedCallback(() {
      setState(() {
        isConnected = true;
        messages.add('✅ Connected to server');
      });
    });

    _socket.setOnMessageCallback((message) {
      print('📨 Received: $message');
      setState(() {
        messages.add('📨 Received: $message');
      });
    });

    _socket.setOnDisconnectedCallback((code, reason) {
      print('❌ Disconnected: $reason (code: $code)');
      setState(() {
        isConnected = false;
        messages.add('❌ Disconnected: $reason (code: $code)');
      });
    });

    _socket.setOnErrorCallback((error) {
      print('⚠️ Error: $error');
      setState(() {
        messages.add('⚠️ Error: $error');
      });
    });
  }

  Future<void> _connect() async {
    try {
      await _socket.connect(
        url: 'wss://your-server.com/ws',
        headers: {
          'User-Agent': 'FlutterSocketClient/1.0',
        },
        // Required for ws:// connections
      );
      setState(() {
        messages.add('🔄 Connecting to socket...');
      });
    } catch (e) {
      print('❌ Connection failed: $e');
      setState(() {
        messages.add('❌ Connection failed: $e');
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _socket.disconnect();
      setState(() {
        isConnected = false;
        messages.add('🛑 Disconnected manually');
      });
    } catch (e) {
      setState(() {
        messages.add('❌ Disconnect failed: $e');
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    try {
      await _socket.sendMessage(_messageController.text);
      setState(() {
        messages.add('📤 Sent: ${_messageController.text}');
        _messageController.clear();
      });
    } catch (e) {
      setState(() {
        messages.add('❌ Send failed: $e');
      });
    }
  }

  Future<void> _startBackgroundService() async {
    try {
      await _socket.startBackgroundService();
      setState(() {
        messages.add('🔄 Background service started');
      });
    } catch (e) {
      setState(() {
        messages.add('❌ Failed to start background service: $e');
      });
    }
  }

  Future<void> _stopBackgroundService() async {
    try {
      await _socket.stopBackgroundService();
      setState(() {
        messages.add('🛑 Background service stopped');
      });
    } catch (e) {
      setState(() {
        messages.add('❌ Failed to stop background service: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Socket Connection Demo'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Connection Status
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green[50] : Colors.red[50],
                  border: Border.all(
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Connection Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? null : _connect,
                      icon: Icon(Icons.link),
                      label: Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? _disconnect : null,
                      icon: Icon(Icons.link_off),
                      label: Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              // Background Service Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startBackgroundService,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Start Background'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stopBackgroundService,
                      icon: Icon(Icons.stop),
                      label: Text('Stop Background'),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Message Input
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message to send',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send),
                    onPressed: isConnected ? _sendMessage : null,
                  ),
                ),
                onSubmitted: isConnected ? (_) => _sendMessage() : null,
              ),

              SizedBox(height: 10),

              ElevatedButton(
                onPressed: isConnected ? _sendMessage : null,
                child: Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),

              SizedBox(height: 20),

              // Messages Header
              Row(
                children: [
                  Text(
                    'Messages:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        messages.clear();
                      });
                    },
                    child: Text('Clear'),
                  ),
                ],
              ),

              SizedBox(height: 10),

              // Messages List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: messages.isEmpty
                      ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: index > 0
                              ? Border(
                            top: BorderSide(color: Colors.grey[300]!),
                          )
                              : null,
                        ),
                        child: Text(
                          messages[index],
                          style: TextStyle(fontSize: 14),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket.disconnect();
    _messageController.dispose();
    super.dispose();
  }
}