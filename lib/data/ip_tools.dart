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
  static const List<PortEntry> ports = [
    PortEntry(20, 'TCP', 'FTP-data', 'Передача данных FTP'),
    PortEntry(21, 'TCP', 'FTP', 'Управляющий канал FTP'),
    PortEntry(22, 'TCP', 'SSH', 'Secure Shell, SFTP, SCP'),
    PortEntry(23, 'TCP', 'Telnet', 'Незашифрованный удалённый доступ'),
    PortEntry(25, 'TCP', 'SMTP', 'Отправка почты'),
    PortEntry(53, 'TCP/UDP', 'DNS', 'Система доменных имён'),
    PortEntry(67, 'UDP', 'DHCP', 'Сервер DHCP'),
    PortEntry(68, 'UDP', 'DHCP', 'Клиент DHCP'),
    PortEntry(69, 'UDP', 'TFTP', 'Простой FTP'),
    PortEntry(80, 'TCP', 'HTTP', 'Веб-трафик'),
    PortEntry(110, 'TCP', 'POP3', 'Получение почты'),
    PortEntry(123, 'UDP', 'NTP', 'Синхронизация времени'),
    PortEntry(137, 'UDP', 'NetBIOS', 'Имена NetBIOS'),
    PortEntry(139, 'TCP', 'NetBIOS', 'Сессии NetBIOS'),
    PortEntry(143, 'TCP', 'IMAP', 'Почта IMAP'),
    PortEntry(161, 'UDP', 'SNMP', 'Мониторинг устройств'),
    PortEntry(162, 'UDP', 'SNMP-trap', 'Уведомления SNMP'),
    PortEntry(389, 'TCP/UDP', 'LDAP', 'Служба каталогов'),
    PortEntry(443, 'TCP', 'HTTPS', 'Зашифрованный веб-трафик'),
    PortEntry(445, 'TCP', 'SMB', 'Общий доступ к файлам Windows'),
    PortEntry(465, 'TCP', 'SMTPS', 'SMTP через SSL'),
    PortEntry(500, 'UDP', 'IKE', 'IPsec / VPN'),
    PortEntry(514, 'UDP', 'Syslog', 'Системные журналы'),
    PortEntry(587, 'TCP', 'SMTP', 'Отправка почты (submission)'),
    PortEntry(631, 'TCP', 'IPP', 'Печать (CUPS)'),
    PortEntry(636, 'TCP', 'LDAPS', 'LDAP через SSL'),
    PortEntry(853, 'TCP', 'DNS-over-TLS', 'Зашифрованный DNS'),
    PortEntry(993, 'TCP', 'IMAPS', 'IMAP через SSL'),
    PortEntry(995, 'TCP', 'POP3S', 'POP3 через SSL'),
    PortEntry(1080, 'TCP', 'SOCKS', 'Прокси SOCKS'),
    PortEntry(1194, 'UDP', 'OpenVPN', 'VPN OpenVPN'),
    PortEntry(1433, 'TCP', 'MSSQL', 'Microsoft SQL Server'),
    PortEntry(1521, 'TCP', 'Oracle', 'Oracle Database'),
    PortEntry(1723, 'TCP', 'PPTP', 'VPN PPTP'),
    PortEntry(2049, 'TCP', 'NFS', 'Сетевая файловая система'),
    PortEntry(2375, 'TCP', 'Docker', 'Docker API (без TLS)'),
    PortEntry(2376, 'TCP', 'Docker', 'Docker API (TLS)'),
    PortEntry(3000, 'TCP', 'Dev', 'Node/Grafana/разработка'),
    PortEntry(3306, 'TCP', 'MySQL', 'MySQL / MariaDB'),
    PortEntry(3389, 'TCP', 'RDP', 'Удалённый рабочий стол'),
    PortEntry(5432, 'TCP', 'PostgreSQL', 'PostgreSQL'),
    PortEntry(5900, 'TCP', 'VNC', 'Удалённый рабочий стол VNC'),
    PortEntry(5985, 'TCP', 'WinRM', 'Удалённое управление Windows'),
    PortEntry(6379, 'TCP', 'Redis', 'Redis'),
    PortEntry(8000, 'TCP', 'HTTP-alt', 'Веб / разработка'),
    PortEntry(8080, 'TCP', 'HTTP-proxy', 'Веб / прокси / Tomcat'),
    PortEntry(8443, 'TCP', 'HTTPS-alt', 'HTTPS альтернативный'),
    PortEntry(9000, 'TCP', 'Portainer', 'Portainer / PHP-FPM'),
    PortEntry(9090, 'TCP', 'Prometheus', 'Prometheus / Cockpit'),
    PortEntry(9200, 'TCP', 'Elasticsearch', 'Elasticsearch'),
    PortEntry(11211, 'TCP', 'Memcached', 'Memcached'),
    PortEntry(27017, 'TCP', 'MongoDB', 'MongoDB'),
    PortEntry(51820, 'UDP', 'WireGuard', 'VPN WireGuard'),
  ];
}
