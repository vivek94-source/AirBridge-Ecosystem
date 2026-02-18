import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class EncryptionLayer {
  static const _deviceIdKey = 'airbridge.device_id';
  static const _trustedPeersKey = 'airbridge.trusted_peers';

  final Uuid _uuid = const Uuid();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _uuid.v4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  String checksum(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<bool> isPeerTrusted(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_trustedPeersKey) ?? const <String>[];
    return values.contains(peerId);
  }

  Future<void> trustPeer(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList(_trustedPeersKey) ?? const <String>[])
        .toSet();
    values.add(peerId);
    await prefs.setStringList(_trustedPeersKey, values.toList()..sort());
  }
}

