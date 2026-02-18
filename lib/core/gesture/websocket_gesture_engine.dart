import 'dart:async';
import 'dart:convert';

import 'package:airbridge/core/gesture/gesture_engine.dart';
import 'package:airbridge/core/models/gesture_event.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketGestureEngine implements GestureEngine {
  WebSocketGestureEngine({
    this.uri = 'ws://127.0.0.1:8765',
  });

  final String uri;
  final StreamController<GestureEvent> _eventsController =
      StreamController<GestureEvent>.broadcast();

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<GestureEvent> get events => _eventsController.stream;

  @override
  Future<void> start() async {
    if (_channel != null) {
      return;
    }
    try {
      _channel = IOWebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(_handleRawEvent);
    } catch (_) {
      // Gesture engine is optional; app remains usable without it.
    }
  }

  void _handleRawEvent(dynamic payload) {
    try {
      final decoded = jsonDecode(payload as String) as Map<String, dynamic>;
      _eventsController.add(GestureEvent.fromJson(decoded));
    } catch (_) {
      // Ignore malformed events.
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }
}

