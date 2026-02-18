enum TransferPhase {
  idle,
  encrypting,
  connecting,
  sending,
  receiving,
  decrypting,
  complete,
  failed,
}

extension TransferPhaseLabel on TransferPhase {
  String get label {
    switch (this) {
      case TransferPhase.idle:
        return 'Idle';
      case TransferPhase.encrypting:
        return 'Encrypting';
      case TransferPhase.connecting:
        return 'Connecting';
      case TransferPhase.sending:
        return 'Sending';
      case TransferPhase.receiving:
        return 'Receiving';
      case TransferPhase.decrypting:
        return 'Decrypting';
      case TransferPhase.complete:
        return 'Complete';
      case TransferPhase.failed:
        return 'Failed';
    }
  }
}

