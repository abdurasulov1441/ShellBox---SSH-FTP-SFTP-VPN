import 'package:easy_localization/easy_localization.dart';

class SubnetInfo {
  const SubnetInfo({
    required this.address,
    required this.prefix,
    required this.netmask,
    required this.wildcard,
    required this.network,
    required this.broadcast,
    required this.firstHost,
    required this.lastHost,
    required this.totalAddresses,
    required this.usableHosts,
    required this.isPrivate,
    required this.ipClass,
  });

  final String address;
  final int prefix;
  final String netmask;
  final String wildcard;
  final String network;
  final String broadcast;
  final String firstHost;
  final String lastHost;
  final int totalAddresses;
  final int usableHosts;
  final bool isPrivate;
  final String ipClass;
}

class IpTools {
  static String intToIp(int value) {
    return '${(value >> 24) & 0xFF}.${(value >> 16) & 0xFF}.${(value >> 8) & 0xFF}.${value & 0xFF}';
  }

  static int? ipToInt(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) {
      return null;
    }
    var result = 0;
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return null;
      }
      result = (result << 8) | octet;
    }
    return result & 0xFFFFFFFF;
  }

  static bool _isPrivate(int ip) {
    final a = (ip >> 24) & 0xFF;
    final b = (ip >> 16) & 0xFF;
    if (a == 10) {
      return true;
    }
    if (a == 172 && b >= 16 && b <= 31) {
      return true;
    }
    if (a == 192 && b == 168) {
      return true;
    }
    if (a == 127) {
      return true;
    }
    if (a == 169 && b == 254) {
      return true;
    }
    return false;
  }

  static String _ipClass(int ip) {
    final a = (ip >> 24) & 0xFF;
    if (a < 128) {
      return 'A';
    }
    if (a < 192) {
      return 'B';
    }
    if (a < 224) {
      return 'C';
    }
    if (a < 240) {
      return 'D (multicast)';
    }
    return 'E (reserved)';
  }

  static SubnetInfo? parse(String input) {
    final trimmed = input.trim();
    String ipPart;
    int prefix;
    if (trimmed.contains('/')) {
      final split = trimmed.split('/');
      if (split.length != 2) {
        return null;
      }
      ipPart = split[0];
      final p = int.tryParse(split[1]);
      if (p == null || p < 0 || p > 32) {
        return null;
      }
      prefix = p;
    } else {
      ipPart = trimmed;
      prefix = 24;
    }
    final ip = ipToInt(ipPart);
    if (ip == null) {
      return null;
    }
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    final wildcard = (~mask) & 0xFFFFFFFF;
    final network = ip & mask;
    final broadcast = network | wildcard;
    final total = prefix >= 31 ? (1 << (32 - prefix)) : (1 << (32 - prefix));
    final usable = prefix >= 31 ? total : (total - 2 < 0 ? 0 : total - 2);
    final first = prefix >= 31 ? network : network + 1;
    final last = prefix >= 31 ? broadcast : broadcast - 1;
    return SubnetInfo(
      address: intToIp(ip),
      prefix: prefix,
      netmask: intToIp(mask),
      wildcard: intToIp(wildcard),
      network: intToIp(network),
      broadcast: intToIp(broadcast),
      firstHost: intToIp(first),
      lastHost: intToIp(last),
      totalAddresses: total,
      usableHosts: usable,
      isPrivate: _isPrivate(ip),
      ipClass: _ipClass(ip),
    );
  }
}

class PortEntry {
  const PortEntry(this.port, this.proto, this.service, this.description);

  final int port;
  final String proto;
  final String service;
  final String description;
}

class PortReference {
  static List<PortEntry> get ports => [
    PortEntry(20, 'TCP', 'FTP-data', 'port.d20'.tr()),
    PortEntry(21, 'TCP', 'FTP', 'port.d21'.tr()),
    PortEntry(22, 'TCP', 'SSH', 'Secure Shell, SFTP, SCP'),
    PortEntry(23, 'TCP', 'Telnet', 'port.d23'.tr()),
    PortEntry(25, 'TCP', 'SMTP', 'port.d25'.tr()),
    PortEntry(53, 'TCP/UDP', 'DNS', 'port.d53'.tr()),
    PortEntry(67, 'UDP', 'DHCP', 'port.d67'.tr()),
    PortEntry(68, 'UDP', 'DHCP', 'port.d68'.tr()),
    PortEntry(69, 'UDP', 'TFTP', 'port.d69'.tr()),
    PortEntry(80, 'TCP', 'HTTP', 'port.d80'.tr()),
    PortEntry(110, 'TCP', 'POP3', 'port.d110'.tr()),
    PortEntry(123, 'UDP', 'NTP', 'port.d123'.tr()),
    PortEntry(137, 'UDP', 'NetBIOS', 'port.d137'.tr()),
    PortEntry(139, 'TCP', 'NetBIOS', 'port.d139'.tr()),
    PortEntry(143, 'TCP', 'IMAP', 'port.d143'.tr()),
    PortEntry(161, 'UDP', 'SNMP', 'port.d161'.tr()),
    PortEntry(162, 'UDP', 'SNMP-trap', 'port.d162'.tr()),
    PortEntry(389, 'TCP/UDP', 'LDAP', 'port.d389'.tr()),
    PortEntry(443, 'TCP', 'HTTPS', 'port.d443'.tr()),
    PortEntry(445, 'TCP', 'SMB', 'port.d445'.tr()),
    PortEntry(465, 'TCP', 'SMTPS', 'port.d465'.tr()),
    PortEntry(500, 'UDP', 'IKE', 'IPsec / VPN'),
    PortEntry(514, 'UDP', 'Syslog', 'port.d514'.tr()),
    PortEntry(587, 'TCP', 'SMTP', 'port.d587'.tr()),
    PortEntry(631, 'TCP', 'IPP', 'port.d631'.tr()),
    PortEntry(636, 'TCP', 'LDAPS', 'port.d636'.tr()),
    PortEntry(853, 'TCP', 'DNS-over-TLS', 'port.d853'.tr()),
    PortEntry(993, 'TCP', 'IMAPS', 'port.d993'.tr()),
    PortEntry(995, 'TCP', 'POP3S', 'port.d995'.tr()),
    PortEntry(1080, 'TCP', 'SOCKS', 'port.d1080'.tr()),
    PortEntry(1194, 'UDP', 'OpenVPN', 'OpenVPN'),
    PortEntry(1433, 'TCP', 'MSSQL', 'Microsoft SQL Server'),
    PortEntry(1521, 'TCP', 'Oracle', 'Oracle Database'),
    PortEntry(1723, 'TCP', 'PPTP', 'PPTP VPN'),
    PortEntry(2049, 'TCP', 'NFS', 'port.d2049'.tr()),
    PortEntry(2375, 'TCP', 'Docker', 'port.d2375'.tr()),
    PortEntry(2376, 'TCP', 'Docker', 'Docker API (TLS)'),
    PortEntry(3000, 'TCP', 'Dev', 'port.d3000'.tr()),
    PortEntry(3306, 'TCP', 'MySQL', 'MySQL / MariaDB'),
    PortEntry(3389, 'TCP', 'RDP', 'port.d3389'.tr()),
    PortEntry(5432, 'TCP', 'PostgreSQL', 'PostgreSQL'),
    PortEntry(5900, 'TCP', 'VNC', 'port.d5900'.tr()),
    PortEntry(5985, 'TCP', 'WinRM', 'port.d5985'.tr()),
    PortEntry(6379, 'TCP', 'Redis', 'Redis'),
    PortEntry(8000, 'TCP', 'HTTP-alt', 'port.d8000'.tr()),
    PortEntry(8080, 'TCP', 'HTTP-proxy', 'port.d8080'.tr()),
    PortEntry(8443, 'TCP', 'HTTPS-alt', 'port.d8443'.tr()),
    PortEntry(9000, 'TCP', 'Portainer', 'Portainer / PHP-FPM'),
    PortEntry(9090, 'TCP', 'Prometheus', 'Prometheus / Cockpit'),
    PortEntry(9200, 'TCP', 'Elasticsearch', 'Elasticsearch'),
    PortEntry(11211, 'TCP', 'Memcached', 'Memcached'),
    PortEntry(27017, 'TCP', 'MongoDB', 'MongoDB'),
    PortEntry(51820, 'UDP', 'WireGuard', 'WireGuard VPN'),
  ];
}
