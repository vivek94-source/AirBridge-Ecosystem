import 'package:airbridge/core/models/device_peer.dart';
import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.peer,
    required this.isSelected,
    required this.onTap,
  });

  final DevicePeer peer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF2EE9E6) : const Color(0x3332DFFF);
    final background = isSelected
        ? const Color(0x1A2EE9E6)
        : const Color(0x110E1B33);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          peer.viaInternet ? Icons.language_rounded : Icons.wifi_tethering,
          color: const Color(0xFF7EE6FF),
        ),
        title: Text(
          peer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          peer.viaInternet ? 'Internet Paired' : '${peer.host}:${peer.port}',
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF2EE9E6))
            : const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

