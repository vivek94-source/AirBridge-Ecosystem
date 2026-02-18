enum GestureType {
  pinch,
  swipeRight,
  swipeLeft,
  openPalm,
  unknown,
}

enum GestureSignalState {
  start,
  update,
  end,
}

class GestureEvent {
  GestureEvent({
    required this.gesture,
    required this.state,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final GestureType gesture;
  final GestureSignalState state;
  final DateTime timestamp;

  factory GestureEvent.fromJson(Map<String, dynamic> json) {
    return GestureEvent(
      gesture: _gestureFromString(json['gesture'] as String? ?? ''),
      state: _stateFromString(json['state'] as String? ?? ''),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }

  static GestureType _gestureFromString(String value) {
    switch (value.toUpperCase()) {
      case 'PINCH':
        return GestureType.pinch;
      case 'SWIPE_RIGHT':
        return GestureType.swipeRight;
      case 'SWIPE_LEFT':
        return GestureType.swipeLeft;
      case 'OPEN_PALM':
        return GestureType.openPalm;
      default:
        return GestureType.unknown;
    }
  }

  static GestureSignalState _stateFromString(String value) {
    switch (value.toUpperCase()) {
      case 'START':
        return GestureSignalState.start;
      case 'UPDATE':
        return GestureSignalState.update;
      case 'END':
        return GestureSignalState.end;
      default:
        return GestureSignalState.update;
    }
  }

  String get label {
    switch (gesture) {
      case GestureType.pinch:
        return 'PINCH';
      case GestureType.swipeRight:
        return 'SWIPE RIGHT';
      case GestureType.swipeLeft:
        return 'SWIPE LEFT';
      case GestureType.openPalm:
        return 'OPEN PALM';
      case GestureType.unknown:
        return 'UNKNOWN';
    }
  }
}

