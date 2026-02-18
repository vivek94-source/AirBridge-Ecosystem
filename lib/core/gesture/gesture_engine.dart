import 'package:airbridge/core/models/gesture_event.dart';

abstract class GestureEngine {
  Stream<GestureEvent> get events;
  Future<void> start();
  Future<void> stop();
}

