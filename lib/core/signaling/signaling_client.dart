import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

class SignalingClient {
  SignalingClient({
    required this.url,
    required this.deviceId,
    required this.deviceName,
  });

  final String url;
  final String deviceId;
  final String deviceName;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    _channel = IOWebSocketChannel.connect(url);
    _subscription = _channel!.stream.listen(_onRawMessage);
    send('register', <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName,
    });
  }

  void _onRawMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      _messageController.add(decoded);
    } catch (_) {
      // Ignore malformed signaling messages.
    }
  }

  void send(String type, [Map<String, dynamic> payload = const {}]) {
    final socket = _channel;
    if (socket == null) {
      return;
    }
    socket.sink.add(jsonEncode(<String, dynamic>{
      'type': type,
      ...payload,
    }));
  }

  void createSession() => send('create_session');

  void joinSession(String code) => send('join_session', <String, dynamic>{
        'code': code,
      });

  void sendSignal({
    required String toPeerId,
    required Map<String, dynamic> data,
  }) {
    send('signal', <String, dynamic>{
      'to': toPeerId,
      'data': data,
    });
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
    await _messageController.close();
  }
}

