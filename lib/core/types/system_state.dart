enum SystemState {
  idle,
  selected,
  sending,
  receiving,
}

extension SystemStateLabel on SystemState {
  String get label {
    switch (this) {
      case SystemState.idle:
        return 'IDLE';
      case SystemState.selected:
        return 'SELECTED';
      case SystemState.sending:
        return 'SENDING';
      case SystemState.receiving:
        return 'RECEIVING';
    }
  }
}

