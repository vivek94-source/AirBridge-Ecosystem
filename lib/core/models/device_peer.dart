class DevicePeer {
  DevicePeer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.viaInternet,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  final String id;
  final String name;
  final String host;
  final int port;
  final bool viaInternet;
  final DateTime discoveredAt;

  DevicePeer copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? viaInternet,
    DateTime? discoveredAt,
  }) {
    return DevicePeer(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      viaInternet: viaInternet ?? this.viaInternet,
      discoveredAt: discoveredAt ?? this.discoveredAt,
    );
  }
}

