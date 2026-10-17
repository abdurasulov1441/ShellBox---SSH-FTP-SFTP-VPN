enum AuthType { password, key }

enum Protocol {
  ssh('SSH', 22),
  ftp('FTP', 21),
  ftps('FTPS', 21);

  const Protocol(this.title, this.defaultPort);

  final String title;
  final int defaultPort;

  bool get isSsh => this == Protocol.ssh;
  bool get isFtp => this == Protocol.ftp || this == Protocol.ftps;

  static Protocol parse(String? value) {
    for (final protocol in Protocol.values) {
      if (protocol.name == value) {
        return protocol;
      }
    }
    return Protocol.ssh;
  }
}

class Host {
  const Host({
    required this.id,
    this.protocol = Protocol.ssh,
    this.label = '',
    this.group = '',
    required this.address,
    this.port = 22,
    required this.username,
    this.auth = AuthType.password,
    this.keyId,
    this.startupCommand = '',
    this.color = 0xFF4F8CFF,
    this.legacy = false,
    this.lastUsed,
  });

  final String id;
  final Protocol protocol;
  final String label;
  final String group;
  final String address;
  final int port;
  final String username;
  final AuthType auth;
  final String? keyId;
  final String startupCommand;
  final int color;
  final bool legacy;
  final DateTime? lastUsed;

  String get title => label.trim().isNotEmpty ? label.trim() : address;

  String get subtitle => port == protocol.defaultPort ? '$username@$address' : '$username@$address:$port';

  String get endpoint => '$address:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'protocol': protocol.name,
        'label': label,
        'group': group,
        'address': address,
        'port': port,
        'username': username,
        'auth': auth.name,
        'keyId': keyId,
        'startupCommand': startupCommand,
        'color': color,
        'legacy': legacy,
        'lastUsed': lastUsed?.millisecondsSinceEpoch,
      };

  factory Host.fromJson(Map<String, dynamic> json) {
    final portValue = json['port'];
    final lastUsedValue = json['lastUsed'];
    final colorValue = json['color'];
    return Host(
      id: json['id'] as String? ?? '',
      protocol: Protocol.parse(json['protocol'] as String?),
      label: json['label'] as String? ?? '',
      group: json['group'] as String? ?? '',
      address: json['address'] as String? ?? '',
      port: portValue is int && portValue > 0 && portValue <= 65535 ? portValue : 22,
      username: json['username'] as String? ?? 'root',
      auth: json['auth'] == AuthType.key.name ? AuthType.key : AuthType.password,
      keyId: json['keyId'] as String?,
      startupCommand: json['startupCommand'] as String? ?? '',
      color: colorValue is int ? colorValue : 0xFF4F8CFF,
      legacy: json['legacy'] as bool? ?? false,
      lastUsed: lastUsedValue is int ? DateTime.fromMillisecondsSinceEpoch(lastUsedValue) : null,
    );
  }

  Host copyWith({
    String? id,
    Protocol? protocol,
    String? label,
    String? group,
    String? address,
    int? port,
    String? username,
    AuthType? auth,
    String? keyId,
    bool clearKey = false,
    String? startupCommand,
    int? color,
    bool? legacy,
    DateTime? lastUsed,
  }) {
    return Host(
      id: id ?? this.id,
      protocol: protocol ?? this.protocol,
      label: label ?? this.label,
      group: group ?? this.group,
      address: address ?? this.address,
      port: port ?? this.port,
      username: username ?? this.username,
      auth: auth ?? this.auth,
      keyId: clearKey ? null : (keyId ?? this.keyId),
      startupCommand: startupCommand ?? this.startupCommand,
      color: color ?? this.color,
      legacy: legacy ?? this.legacy,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}

class SshKey {
  const SshKey({
    required this.id,
    required this.name,
    required this.type,
    required this.publicKey,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final String publicKey;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'publicKey': publicKey,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory SshKey.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return SshKey(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Key',
      type: json['type'] as String? ?? '',
      publicKey: json['publicKey'] as String? ?? '',
      createdAt: created is int ? DateTime.fromMillisecondsSinceEpoch(created) : DateTime.now(),
    );
  }

  SshKey copyWith({String? name}) {
    return SshKey(id: id, name: name ?? this.name, type: type, publicKey: publicKey, createdAt: createdAt);
  }
}

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.address,
    required this.dns,
    required this.createdAt,
    this.lastUsed,
  });

  final String id;
  final String name;
  final String endpoint;
  final String address;
  final String dns;
  final DateTime createdAt;
  final DateTime? lastUsed;

  String get host => endpoint.contains(':') ? endpoint.substring(0, endpoint.lastIndexOf(':')) : endpoint;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'endpoint': endpoint,
        'address': address,
        'dns': dns,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastUsed': lastUsed?.millisecondsSinceEpoch,
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final used = json['lastUsed'];
    return VpnProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'VPN',
      endpoint: json['endpoint'] as String? ?? '',
      address: json['address'] as String? ?? '',
      dns: json['dns'] as String? ?? '',
      createdAt: created is int ? DateTime.fromMillisecondsSinceEpoch(created) : DateTime.now(),
      lastUsed: used is int ? DateTime.fromMillisecondsSinceEpoch(used) : null,
    );
  }

  VpnProfile copyWith({String? name, DateTime? lastUsed}) {
    return VpnProfile(
      id: id,
      name: name ?? this.name,
      endpoint: endpoint,
      address: address,
      dns: dns,
      createdAt: createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  static ({String endpoint, String address, String dns})? parseConfig(String config) {
    String? endpoint;
    String? address;
    String? dns;
    var hasInterface = false;
    var hasPeer = false;
    for (final rawLine in config.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final lower = line.toLowerCase();
      if (lower == '[interface]') {
        hasInterface = true;
        continue;
      }
      if (lower == '[peer]') {
        hasPeer = true;
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final key = line.substring(0, eq).trim().toLowerCase();
      final value = line.substring(eq + 1).trim();
      if (key == 'endpoint') {
        endpoint = value;
      } else if (key == 'address') {
        address = value;
      } else if (key == 'dns') {
        dns = value;
      }
    }
    if (!hasInterface || !hasPeer || endpoint == null || endpoint.isEmpty) {
      return null;
    }
    return (endpoint: endpoint, address: address ?? '', dns: dns ?? '');
  }
}

class Snippet {
  const Snippet({required this.id, required this.name, required this.command});

  final String id;
  final String name;
  final String command;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'command': command};

  factory Snippet.fromJson(Map<String, dynamic> json) {
    return Snippet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
    );
  }
}
