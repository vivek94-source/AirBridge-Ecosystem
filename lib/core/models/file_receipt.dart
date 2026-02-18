class FileReceipt {
  FileReceipt({
    required this.path,
    required this.fileName,
    required this.fromPeerId,
    required this.byteSize,
    required this.sha256,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  final String path;
  final String fileName;
  final String fromPeerId;
  final int byteSize;
  final String sha256;
  final DateTime receivedAt;
}

