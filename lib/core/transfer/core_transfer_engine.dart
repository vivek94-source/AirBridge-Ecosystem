import 'dart:io';

import 'package:airbridge/core/models/device_peer.dart';
import 'package:airbridge/core/models/file_receipt.dart';
import 'package:airbridge/core/models/transfer_progress.dart';

abstract class CoreTransferEngine {
  Stream<TransferProgress> get progressStream;
  Stream<FileReceipt> get incomingFiles;

  Future<void> initialize();

  Future<void> connectToPeer(DevicePeer peer);

  Future<void> handleSignal({
    required String fromPeerId,
    required Map<String, dynamic> signalPayload,
  });

  Future<void> sendFile({
    required File file,
    required DevicePeer peer,
  });

  Future<void> dispose();
}

