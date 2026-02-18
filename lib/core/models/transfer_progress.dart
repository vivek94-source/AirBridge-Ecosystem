import 'package:airbridge/core/types/transfer_phase.dart';

class TransferProgress {
  const TransferProgress({
    required this.phase,
    required this.progress,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.message,
  });

  final TransferPhase phase;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final String? message;

  factory TransferProgress.idle() {
    return const TransferProgress(
      phase: TransferPhase.idle,
      progress: 0,
    );
  }

  TransferProgress copyWith({
    TransferPhase? phase,
    double? progress,
    int? bytesTransferred,
    int? totalBytes,
    String? message,
  }) {
    return TransferProgress(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      message: message ?? this.message,
    );
  }
}

