import 'package:airbridge/core/models/gesture_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gesture event parses uppercase payload', () {
    final event = GestureEvent.fromJson(<String, dynamic>{
      'gesture': 'SWIPE_RIGHT',
      'state': 'START',
    });

    expect(event.gesture, GestureType.swipeRight);
    expect(event.state, GestureSignalState.start);
  });
}

