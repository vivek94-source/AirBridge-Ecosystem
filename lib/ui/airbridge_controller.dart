import 'dart:async';
import 'dart:io';

import 'package:airbridge/core/discovery/discovery_manager.dart';
import 'package:airbridge/core/encryption/encryption_layer.dart';
import 'package:airbridge/core/gesture/gesture_engine.dart';
import 'package:airbridge/core/gesture/websocket_gesture_engine.dart';
import 'package:airbridge/core/models/device_peer.dart';
import 'package:airbridge/core/models/file_receipt.dart';
import 'package:airbridge/core/models/gesture_event.dart';
import 'package:airbridge/core/models/transfer_progress.dart';
import 'package:airbridge/core/signaling/signaling_client.dart';
import 'package:airbridge/core/transfer/core_transfer_engine.dart';
import 'package:airbridge/core/transfer/webrtc_transfer_engine.dart';
import 'package:airbridge/core/types/system_state.dart';
import 'package:airbridge/core/types/transfer_phase.dart';
import 'package:airbridge/utils/cli_animation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class AirBridgeController extends ChangeNotifier {
  AirBridgeController({
    this.signalingUrl = 'ws://127.0.0.1:8080',
    GestureEngine? gestureEngine,
    EncryptionLayer? encryptionLayer,
  })  : _gestureEngine = gestureEngine ?? WebSocketGestureEngine(),
        _encryptionLayer = encryptionLayer ?? EncryptionLayer();

  final String signalingUrl;
  final GestureEngine _gestureEngine;
  final EncryptionLayer _encryptionLayer;

  late final DiscoveryManager _discoveryManager;
  late final SignalingClient _signalingClient;
  late final CoreTransferEngine _transferEngine;

  StreamSubscription<GestureEvent>? _gestureSub;
  StreamSubscription<List<DevicePeer>>? _discoverySub;
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<FileReceipt>? _incomingFileSub;

  bool _initialized = false;
  bool _isPickingFile = false;
  String? _selectedFilePath;

  String deviceId = '';
  String deviceName = '';

  SystemState systemState = SystemState.idle;
  TransferProgress transferProgress = TransferProgress.idle();
  String gestureStatus = 'OPEN PALM';
  List<DevicePeer> nearbyDevices = const <DevicePeer>[];
  DevicePeer? selectedPeer;
  String? selectedFileName;

  String? pairingCode;
  DevicePeer? pendingTrustPeer;
  final List<String> activityLog = <String>[];

  bool get hasPendingTrust => pendingTrustPeer != null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    deviceName = Platform.localHostname;
    deviceId = await _encryptionLayer.getOrCreateDeviceId();

    _discoveryManager = DiscoveryManager();
    _signalingClient = SignalingClient(
      url: signalingUrl,
      deviceId: deviceId,
      deviceName: deviceName,
    );
    _transferEngine = WebRtcTransferEngine(
      signalingClient: _signalingClient,
      encryptionLayer: _encryptionLayer,
    );

    _discoverySub = _discoveryManager.peers.listen((devices) {
      nearbyDevices = devices;
      notifyListeners();
    });
    _signalSub = _signalingClient.messages.listen(_handleSignalingMessage);
    _progressSub = _transferEngine.progressStream.listen((progress) {
      transferProgress = progress;
      if (progress.phase == TransferPhase.sending) {
        systemState = SystemState.sending;
      } else if (progress.phase == TransferPhase.receiving) {
        systemState = SystemState.receiving;
      } else if (progress.phase == TransferPhase.complete ||
          progress.phase == TransferPhase.failed) {
        systemState = selectedFileName == null
            ? SystemState.idle
            : SystemState.selected;
      }
      notifyListeners();
    });

    _incomingFileSub = _transferEngine.incomingFiles.listen((receipt) {
      _log('File saved: ${receipt.fileName} (${receipt.path})');
      unawaited(CliAnimation.playReceiveIfEnabled());
      systemState = SystemState.idle;
      notifyListeners();
    });

    await _transferEngine.initialize();
    await _discoveryManager.start();

    try {
      await _signalingClient.connect();
      _log('Signaling connected');
    } catch (_) {
      _log('Signaling unavailable (local-only mode)');
    }

    try {
      await _gestureEngine.start();
      _gestureSub = _gestureEngine.events.listen(_handleGestureEvent);
      _log('Gesture engine connected');
    } catch (_) {
      _log('Gesture engine unavailable, manual mode active');
    }

    _log('System Status: ${systemState.label}');
    notifyListeners();
  }

  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String? ?? '';
    switch (type) {
      case 'session_created':
        pairingCode = message['code'] as String?;
        _log('Session code ready: ${pairingCode ?? 'N/A'}');
        notifyListeners();
        return;
      case 'peer_matched':
        final peerData = message['peer'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final peer = DevicePeer(
          id: peerData['id'] as String? ?? 'unknown-peer',
          name: peerData['name'] as String? ?? 'Unknown Peer',
          host: peerData['host'] as String? ?? 'relay',
          port: (peerData['port'] as num?)?.toInt() ?? 0,
          viaInternet: true,
        );
        _discoveryManager.addInternetPeer(peer);
        _log('Paired with ${peer.name}');
        return;
      case 'signal':
        final fromPeerId = message['from'] as String?;
        final data = message['data'] as Map<String, dynamic>?;
        if (fromPeerId != null && data != null) {
          _transferEngine.handleSignal(
            fromPeerId: fromPeerId,
            signalPayload: data,
          );
        }
        return;
      case 'error':
        _log('Signaling error: ${message['message'] ?? 'unknown'}');
        notifyListeners();
        return;
      default:
        return;
    }
  }

  void _handleGestureEvent(GestureEvent event) {
    gestureStatus = '${event.label} ${event.state.name.toUpperCase()}';
    notifyListeners();

    if (event.state != GestureSignalState.start) {
      return;
    }

    switch (event.gesture) {
      case GestureType.pinch:
        pickFile();
        break;
      case GestureType.swipeRight:
        sendSelectedFile();
        break;
      case GestureType.swipeLeft:
        cancelSelection();
        break;
      case GestureType.openPalm:
        if (selectedFileName == null) {
          systemState = SystemState.idle;
          notifyListeners();
        }
        break;
      case GestureType.unknown:
        break;
    }
  }

  void selectPeer(DevicePeer peer) {
    selectedPeer = peer;
    _log('Selected target: ${peer.name}');
    notifyListeners();
  }

  Future<void> createSession() async {
    _signalingClient.createSession();
  }

  Future<void> joinSession(String code) async {
    if (code.trim().length != 6) {
      _log('Session code must be 6 digits');
      notifyListeners();
      return;
    }
    _signalingClient.joinSession(code.trim());
  }

  Future<void> pickFile() async {
    if (_isPickingFile) {
      return;
    }
    _isPickingFile = true;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final chosen = result.files.single;
      if (chosen.path == null) {
        return;
      }

      selectedFileName = chosen.name;
      _selectedFilePath = chosen.path!;
      systemState = SystemState.selected;
      _log('File selected: ${chosen.name}');
      unawaited(CliAnimation.playSelectionIfEnabled(chosen.name));
      notifyListeners();
    } finally {
      _isPickingFile = false;
    }
  }

  void cancelSelection() {
    selectedFileName = null;
    _selectedFilePath = null;
    transferProgress = TransferProgress.idle();
    systemState = SystemState.idle;
    _log('Selection canceled');
    notifyListeners();
  }

  Future<void> sendSelectedFile() async {
    final path = _selectedFilePath;
    final peer = selectedPeer;
    if (path == null || selectedFileName == null) {
      _log('No file selected');
      notifyListeners();
      return;
    }
    if (peer == null) {
      _log('Select a target device first');
      notifyListeners();
      return;
    }

    final trusted = await _encryptionLayer.isPeerTrusted(peer.id);
    if (!trusted) {
      pendingTrustPeer = peer;
      _log('First-time pairing confirmation required for ${peer.name}');
      notifyListeners();
      return;
    }

    systemState = SystemState.sending;
    unawaited(CliAnimation.playSendIfEnabled());
    notifyListeners();

    try {
      await _transferEngine.sendFile(
        file: File(path),
        peer: peer,
      );
      _log('Transfer complete');
    } catch (error) {
      transferProgress = const TransferProgress(
        phase: TransferPhase.failed,
        progress: 1,
        message: 'Transfer failed',
      );
      _log('Transfer failed: $error');
    } finally {
      if (selectedFileName != null) {
        systemState = SystemState.selected;
      } else {
        systemState = SystemState.idle;
      }
      notifyListeners();
    }
  }

  Future<void> trustPendingPeer() async {
    final peer = pendingTrustPeer;
    if (peer == null) {
      return;
    }
    await _encryptionLayer.trustPeer(peer.id);
    pendingTrustPeer = null;
    _log('Trusted peer: ${peer.name}');
    notifyListeners();
  }

  void dismissPendingTrust() {
    pendingTrustPeer = null;
    notifyListeners();
  }

  void _log(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    activityLog.insert(0, '[$hh:$mm:$ss] $message');
    if (activityLog.length > 20) {
      activityLog.removeRange(20, activityLog.length);
    }
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    _discoverySub?.cancel();
    _signalSub?.cancel();
    _progressSub?.cancel();
    _incomingFileSub?.cancel();
    _gestureEngine.stop();
    _discoveryManager.stop();
    _signalingClient.disconnect();
    _transferEngine.dispose();
    super.dispose();
  }
}

