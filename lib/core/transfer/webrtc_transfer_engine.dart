import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:airbridge/core/encryption/encryption_layer.dart';
import 'package:airbridge/core/models/device_peer.dart';
import 'package:airbridge/core/models/file_receipt.dart';
import 'package:airbridge/core/models/transfer_progress.dart';
import 'package:airbridge/core/signaling/signaling_client.dart';
import 'package:airbridge/core/transfer/core_transfer_engine.dart';
import 'package:airbridge/core/types/transfer_phase.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

class WebRtcTransferEngine implements CoreTransferEngine {
  WebRtcTransferEngine({
    required this.signalingClient,
    required this.encryptionLayer,
  });

  final SignalingClient signalingClient;
  final EncryptionLayer encryptionLayer;

  final StreamController<TransferProgress> _progressController =
      StreamController<TransferProgress>.broadcast();
  final StreamController<FileReceipt> _incomingController =
      StreamController<FileReceipt>.broadcast();

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  DevicePeer? _activePeer;
  Completer<void>? _channelReady;

  BytesBuilder _incomingBytes = BytesBuilder();
  Map<String, dynamic>? _incomingMeta;
  String? _incomingFromPeerId;

  @override
  Stream<TransferProgress> get progressStream => _progressController.stream;

  @override
  Stream<FileReceipt> get incomingFiles => _incomingController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> connectToPeer(DevicePeer peer) async {
    _activePeer = peer;
    await _ensurePeerConnection();
    await _openDataChannelIfMissing();
    await _createAndSendOffer(peer.id);
  }

  Future<void> _ensurePeerConnection() async {
    if (_peerConnection != null) {
      return;
    }
    _peerConnection = await createPeerConnection(<String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _peerConnection!.onIceCandidate = (candidate) {
      final peer = _activePeer;
      if (peer == null) {
        return;
      }
      signalingClient.sendSignal(
        toPeerId: peer.id,
        data: <String, dynamic>{
          'kind': 'webrtc_ice',
          'candidate': <String, dynamic>{
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        },
      );
    };

    _peerConnection!.onDataChannel = (channel) {
      _bindDataChannel(channel);
    };
  }

  Future<void> _openDataChannelIfMissing() async {
    if (_dataChannel != null) {
      return;
    }

    final dataChannel = await _peerConnection!.createDataChannel(
      'airbridge-file',
      RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30,
    );
    _bindDataChannel(dataChannel);
  }

  void _bindDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    _channelReady ??= Completer<void>();

    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          _channelReady != null &&
          !_channelReady!.isCompleted) {
        _channelReady!.complete();
      }
    };

    channel.onMessage = _handleDataMessage;
  }

  Future<void> _createAndSendOffer(String toPeerId) async {
    _progressController.add(
      const TransferProgress(
        phase: TransferPhase.connecting,
        progress: 0.2,
        message: 'Creating offer...',
      ),
    );
    final offer = await _peerConnection!.createOffer(<String, dynamic>{});
    await _peerConnection!.setLocalDescription(offer);
    signalingClient.sendSignal(
      toPeerId: toPeerId,
      data: <String, dynamic>{
        'kind': 'webrtc_offer',
        'sdp': offer.sdp,
        'type': offer.type,
      },
    );
  }

  @override
  Future<void> handleSignal({
    required String fromPeerId,
    required Map<String, dynamic> signalPayload,
  }) async {
    final kind = signalPayload['kind'] as String? ?? '';
    await _ensurePeerConnection();

    if (_activePeer == null || _activePeer!.id != fromPeerId) {
      _activePeer = DevicePeer(
        id: fromPeerId,
        name: fromPeerId,
        host: '',
        port: 0,
        viaInternet: true,
      );
    }

    switch (kind) {
      case 'webrtc_offer':
        final sdp = signalPayload['sdp'] as String? ?? '';
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'offer'),
        );
        await _openDataChannelIfMissing();
        final answer = await _peerConnection!.createAnswer(<String, dynamic>{});
        await _peerConnection!.setLocalDescription(answer);
        signalingClient.sendSignal(
          toPeerId: fromPeerId,
          data: <String, dynamic>{
            'kind': 'webrtc_answer',
            'sdp': answer.sdp,
            'type': answer.type,
          },
        );
        break;

      case 'webrtc_answer':
        final sdp = signalPayload['sdp'] as String? ?? '';
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
        break;

      case 'webrtc_ice':
        final candidate = signalPayload['candidate'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final iceCandidate = RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          candidate['sdpMLineIndex'] as int?,
        );
        await _peerConnection!.addCandidate(iceCandidate);
        break;
    }
  }

  @override
  Future<void> sendFile({
    required File file,
    required DevicePeer peer,
  }) async {
    if (_activePeer == null || _activePeer!.id != peer.id) {
      await connectToPeer(peer);
    }

    _channelReady ??= Completer<void>();
    if (!_channelReady!.isCompleted) {
      _progressController.add(
        const TransferProgress(
          phase: TransferPhase.connecting,
          progress: 0.6,
          message: 'Waiting for secure channel...',
        ),
      );
      await _channelReady!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Data channel not ready'),
      );
    }

    final bytes = await file.readAsBytes();
    final total = bytes.length;
    final checksum = encryptionLayer.checksum(bytes);

    _progressController.add(
      const TransferProgress(
        phase: TransferPhase.encrypting,
        progress: 1,
        message: 'DTLS channel established, preparing payload...',
      ),
    );

    _dataChannel!.send(
      RTCDataChannelMessage(
        jsonEncode(<String, dynamic>{
          'kind': 'file_meta',
          'name': file.uri.pathSegments.isEmpty
              ? 'airbridge_file.bin'
              : file.uri.pathSegments.last,
          'size': total,
          'sha256': checksum,
        }),
      ),
    );

    const chunkSize = 16 * 1024;
    var sent = 0;
    while (sent < total) {
      final end = (sent + chunkSize > total) ? total : sent + chunkSize;
      _dataChannel!.send(
        RTCDataChannelMessage.fromBinary(
          Uint8List.sublistView(bytes, sent, end),
        ),
      );
      sent = end;
      _progressController.add(
        TransferProgress(
          phase: TransferPhase.sending,
          progress: sent / total,
          bytesTransferred: sent,
          totalBytes: total,
          message: 'Sending ${file.uri.pathSegments.last}',
        ),
      );
    }

    _dataChannel!.send(
      RTCDataChannelMessage(
        jsonEncode(<String, dynamic>{'kind': 'file_complete'}),
      ),
    );

    _progressController.add(
      const TransferProgress(
        phase: TransferPhase.complete,
        progress: 1,
        message: 'Transfer complete',
      ),
    );
  }

  void _handleDataMessage(RTCDataChannelMessage message) {
    if (!message.isBinary) {
      _handleControlPacket(message.text);
      return;
    }

    final chunk = message.binary;
    _incomingBytes.add(chunk);

    final expected = (_incomingMeta?['size'] as int?) ?? 0;
    final current = _incomingBytes.length;
    if (expected > 0) {
      _progressController.add(
        TransferProgress(
          phase: TransferPhase.receiving,
          progress: current / expected,
          bytesTransferred: current,
          totalBytes: expected,
          message: 'Receiving ${_incomingMeta?['name'] ?? 'file'}',
        ),
      );
    }
  }

  Future<void> _handleControlPacket(String packet) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(packet) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final kind = payload['kind'] as String? ?? '';
    switch (kind) {
      case 'file_meta':
        _incomingMeta = payload;
        _incomingBytes = BytesBuilder();
        _incomingFromPeerId = _activePeer?.id;
        _progressController.add(
          TransferProgress(
            phase: TransferPhase.receiving,
            progress: 0,
            bytesTransferred: 0,
            totalBytes: payload['size'] as int? ?? 0,
            message: 'Incoming secure transfer...',
          ),
        );
        break;

      case 'file_complete':
        await _persistIncomingFile();
        break;
    }
  }

  Future<void> _persistIncomingFile() async {
    final meta = _incomingMeta;
    if (meta == null) {
      return;
    }

    _progressController.add(
      const TransferProgress(
        phase: TransferPhase.decrypting,
        progress: 1,
        message: 'Verifying and writing file...',
      ),
    );

    final data = _incomingBytes.takeBytes();
    final computedSha = encryptionLayer.checksum(data);
    final expectedSha = meta['sha256'] as String? ?? '';
    if (expectedSha.isNotEmpty && expectedSha != computedSha) {
      _progressController.add(
        const TransferProgress(
          phase: TransferPhase.failed,
          progress: 1,
          message: 'Checksum mismatch',
        ),
      );
      return;
    }

    final downloads = await getDownloadsDirectory();
    final docs = await getApplicationDocumentsDirectory();
    final root = downloads ?? docs;
    final safeName = meta['name'] as String? ?? 'airbridge_file.bin';
    final target = File('${root.path}${Platform.pathSeparator}$safeName');
    await target.writeAsBytes(data, flush: true);

    _incomingController.add(
      FileReceipt(
        path: target.path,
        fileName: safeName,
        fromPeerId: _incomingFromPeerId ?? 'unknown',
        byteSize: data.length,
        sha256: computedSha,
      ),
    );

    _progressController.add(
      const TransferProgress(
        phase: TransferPhase.complete,
        progress: 1,
        message: 'File saved successfully',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    await _progressController.close();
    await _incomingController.close();
  }
}

