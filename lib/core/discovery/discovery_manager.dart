import 'dart:async';

import 'package:airbridge/core/models/device_peer.dart';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveryManager {
  DiscoveryManager({
    this.serviceType = '_airbridge._tcp.local',
  });

  final String serviceType;
  final MDnsClient _mdns = MDnsClient();
  final Map<String, DevicePeer> _peers = <String, DevicePeer>{};
  final StreamController<List<DevicePeer>> _peersController =
      StreamController<List<DevicePeer>>.broadcast();

  Timer? _poller;
  bool _started = false;

  Stream<List<DevicePeer>> get peers => _peersController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    await _mdns.start();
    _poller = Timer.periodic(const Duration(seconds: 6), (_) => scanNow());
    await scanNow();
  }

  Future<void> scanNow() async {
    final discovered = <String, DevicePeer>{};
    try {
      await for (final ptr in _mdns.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceType),
      )) {
        await for (final srv in _mdns.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          String host = srv.target;
          await for (final ip in _mdns.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            host = ip.address.address;
            break;
          }

          final peer = DevicePeer(
            id: '${srv.target}:${srv.port}',
            name: srv.target.replaceAll('.local', ''),
            host: host,
            port: srv.port,
            viaInternet: false,
          );
          discovered[peer.id] = peer;
        }
      }
    } catch (_) {
      // mDNS is best-effort; discovery can continue with internet pairing.
    }

    _peers
      ..removeWhere((key, value) => !value.viaInternet)
      ..addAll(discovered);
    _emitPeers();
  }

  void addInternetPeer(DevicePeer peer) {
    _peers[peer.id] = peer.copyWith(viaInternet: true);
    _emitPeers();
  }

  void _emitPeers() {
    final values = _peers.values.toList()
      ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
    _peersController.add(values);
  }

  Future<void> stop() async {
    _poller?.cancel();
    _poller = null;
    _started = false;
    _mdns.stop();
    await _peersController.close();
  }
}

