enum SuggestionKind { history, snippet, command, next }

class Suggestion {
  const Suggestion({required this.label, required this.insert, required this.kind});

  final String label;
  final String insert;
  final SuggestionKind kind;
}

class CommandIntel {
  static const List<String> commands = [
    'ls',
    'cd',
    'pwd',
    'cat',
    'less',
    'tail',
    'head',
    'grep',
    'find',
    'sudo',
    'su',
    'apt',
    'apt-get',
    'dnf',
    'yum',
    'pacman',
    'apk',
    'snap',
    'systemctl',
    'service',
    'journalctl',
    'dmesg',
    'ps',
    'top',
    'htop',
    'kill',
    'killall',
    'pkill',
    'nice',
    'nohup',
    'df',
    'du',
    'free',
    'mount',
    'umount',
    'lsblk',
    'fdisk',
    'blkid',
    'tar',
    'gzip',
    'gunzip',
    'zip',
    'unzip',
    'xz',
    'curl',
    'wget',
    'ssh',
    'scp',
    'sftp',
    'rsync',
    'ftp',
    'git',
    'docker',
    'docker-compose',
    'kubectl',
    'podman',
    'nano',
    'vim',
    'vi',
    'emacs',
    'chmod',
    'chown',
    'chgrp',
    'umask',
    'useradd',
    'usermod',
    'userdel',
    'groupadd',
    'passwd',
    'whoami',
    'id',
    'who',
    'w',
    'last',
    'uname',
    'hostname',
    'hostnamectl',
    'uptime',
    'date',
    'cal',
    'history',
    'clear',
    'exit',
    'export',
    'env',
    'printenv',
    'set',
    'alias',
    'source',
    'netstat',
    'ss',
    'ip',
    'ifconfig',
    'ping',
    'traceroute',
    'mtr',
    'dig',
    'nslookup',
    'host',
    'nmap',
    'nc',
    'ncat',
    'socat',
    'tcpdump',
    'iptables',
    'nft',
    'ufw',
    'firewall-cmd',
    'crontab',
    'at',
    'systemd-analyze',
    'awk',
    'sed',
    'sort',
    'uniq',
    'wc',
    'xargs',
    'cut',
    'tr',
    'tee',
    'column',
    'echo',
    'printf',
    'touch',
    'mkdir',
    'rmdir',
    'rm',
    'cp',
    'mv',
    'ln',
    'stat',
    'file',
    'readlink',
    'which',
    'whereis',
    'locate',
    'updatedb',
    'man',
    'watch',
    'reboot',
    'shutdown',
    'poweroff',
    'systemctl',
    'base64',
    'md5sum',
    'sha256sum',
    'openssl',
    'gpg',
    'ssh-keygen',
  ];

  static const Map<String, List<String>> nextWord = {
    'sudo': ['apt', 'systemctl', 'nano', 'su -', 'journalctl', 'docker', 'ufw', 'iptables', 'reboot', 'poweroff', '-i'],
    'apt': ['update', 'upgrade', 'install', 'remove', 'purge', 'autoremove', 'search', 'show', 'list', 'full-upgrade'],
    'apt-get': ['update', 'upgrade', 'install', 'remove', 'purge', 'dist-upgrade', 'autoremove'],
    'dnf': ['install', 'remove', 'update', 'upgrade', 'search', 'info', 'list'],
    'yum': ['install', 'remove', 'update', 'search', 'info'],
    'pacman': ['-Syu', '-S', '-R', '-Rns', '-Ss', '-Qe', '-Qdt'],
    'apk': ['add', 'del', 'update', 'upgrade', 'search'],
    'snap': ['install', 'remove', 'list', 'refresh'],
    'systemctl': [
      'status',
      'start',
      'stop',
      'restart',
      'reload',
      'enable',
      'disable',
      'mask',
      'is-active',
      'is-enabled',
      'list-units',
      'list-unit-files',
      'daemon-reload',
    ],
    'service': ['status', 'start', 'stop', 'restart', 'reload', '--status-all'],
    'journalctl': ['-u', '-f', '-n', '-xe', '--no-pager', '-b', '-p', '--since', '-k', '-r'],
    'git': [
      'status',
      'add',
      'commit',
      'push',
      'pull',
      'clone',
      'log',
      'diff',
      'checkout',
      'branch',
      'merge',
      'stash',
      'remote',
      'fetch',
      'reset',
      'rebase',
      'tag',
      'switch',
    ],
    'docker': [
      'ps',
      'images',
      'run',
      'exec',
      'logs',
      'stop',
      'start',
      'restart',
      'rm',
      'rmi',
      'pull',
      'push',
      'build',
      'compose',
      'inspect',
      'stats',
      'network',
      'volume',
      'system',
    ],
    'docker-compose': ['up', 'down', 'ps', 'logs', 'restart', 'build', 'pull', 'exec'],
    'kubectl': ['get', 'describe', 'logs', 'apply', 'delete', 'exec', 'rollout', 'scale', 'edit', 'top'],
    'ss': ['-tulpn', '-tlnp', '-s', '-tn', '-unp', '-plant'],
    'ip': ['a', 'addr', 'link', 'route', 'r', 'neigh', '-s'],
    'ufw': ['status', 'enable', 'disable', 'allow', 'deny', 'delete', 'reload', 'reset'],
    'iptables': ['-L -n -v', '-L', '-F', '-A', '-D', '-t nat -L', '-S'],
    'nft': ['list ruleset', 'list tables', 'flush ruleset'],
    'firewall-cmd': ['--list-all', '--state', '--reload', '--add-port', '--permanent'],
    'nmap': ['-sV', '-sC', '-sS', '-sU', '-A', '-p-', '-Pn', '-O', '-T4', '-oN', '--script', '-v'],
    'find': [
      '/ -perm -4000 -type f 2>/dev/null',
      '/ -writable -type d 2>/dev/null',
      '. -name',
      '/ -name',
      '. -type f',
      '/ -type f -mtime -1',
    ],
    'chmod': ['+x', '755', '644', '700', '600', '-R', '777'],
    'chown': ['-R', 'root:root'],
    'kill': ['-9', '-15', '-l'],
    'pkill': ['-9', '-f'],
    'tar': ['-xzvf', '-czvf', '-xvf', '-cvf', '-tzvf', '-xjvf'],
    'ps': ['aux', '-ef', 'aux | grep', '-eo pid,ppid,cmd,%mem,%cpu'],
    'crontab': ['-l', '-e', '-r', '-u'],
    'curl': ['-I', '-s', '-L', '-o', '-X', '-H', '-d', '-k', '-sSL', '--resolve'],
    'wget': ['-O', '-c', '-q', '--no-check-certificate'],
    'ln': ['-s', '-sf'],
    'du': ['-sh', '-h', '-sh *', '-ah'],
    'free': ['-h', '-m', '-g'],
    'df': ['-h', '-i', '-hT'],
    'grep': ['-r', '-i', '-n', '-v', '-E', '-rn', '--color', '-c', '-l', '-A', '-B'],
    'dig': ['+short', 'A', 'AAAA', 'MX', 'TXT', 'NS', 'ANY', '-x'],
    'openssl': ['s_client', 'x509', 'genrsa', 'req', 'rand', 'enc'],
    'rm': ['-rf', '-r', '-f', '-i'],
    'cp': ['-r', '-a', '-v', '-rf'],
    'mv': ['-v', '-f', '-i'],
    'mkdir': ['-p', '-pv'],
    'tail': ['-f', '-n', '-f /var/log/syslog'],
    'head': ['-n'],
    'su': ['-', 'root', '- root'],
    'uname': ['-a', '-r', '-m'],
    'chattr': ['+i', '-i'],
  };

  static const List<String> templates = [
    'sudo apt update && sudo apt upgrade -y',
    'sudo apt install ',
    'systemctl status ',
    'systemctl restart ',
    'systemctl enable --now ',
    'journalctl -u ',
    'journalctl -xe --no-pager',
    'journalctl -n 100 --no-pager',
    'journalctl -f',
    'docker ps -a',
    'docker logs -f ',
    'docker exec -it ',
    'docker compose up -d',
    'docker compose logs -f',
    'ss -tulpn',
    'ps aux | grep ',
    'df -h',
    'du -sh * | sort -h',
    'free -h',
    'tail -f /var/log/syslog',
    'tail -f /var/log/auth.log',
    'find / -perm -4000 -type f 2>/dev/null',
    'find / -writable -type d 2>/dev/null',
    'uname -a',
    'cat /etc/os-release',
    'ip a',
    'curl -sSL ',
    'curl -I ',
    'chmod +x ',
    'chown -R ',
    'nmap -sV -sC ',
    'nmap -p- -T4 -Pn ',
    'grep -rn ',
    'history | tail -50',
  ];

  static List<Suggestion> suggest({
    required String line,
    required List<String> history,
    required List<String> snippetCommands,
    int limit = 12,
  }) {
    if (line.isEmpty) {
      return const [];
    }
    final lower = line.toLowerCase();
    final seen = <String>{};
    final result = <Suggestion>[];

    void add(String resulting, SuggestionKind kind, {String? label}) {
      if (resulting.length <= line.length || !resulting.startsWith(line)) {
        return;
      }
      if (result.length >= limit || !seen.add(resulting)) {
        return;
      }
      result.add(Suggestion(label: label ?? resulting, insert: resulting.substring(line.length), kind: kind));
    }

    for (final entry in history) {
      if (entry.toLowerCase().startsWith(lower)) {
        add(entry, SuggestionKind.history);
      }
    }
    for (final entry in snippetCommands) {
      if (entry.toLowerCase().startsWith(lower)) {
        add(entry, SuggestionKind.snippet);
      }
    }

    final endsWithSpace = line.endsWith(' ');
    final tokens = line.trimRight().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (endsWithSpace) {
      final key = tokens.isEmpty ? '' : tokens.last;
      final options = nextWord[key] ?? (tokens.isNotEmpty ? nextWord[tokens.first] : null) ?? const [];
      for (final opt in options) {
        add('$line$opt ', SuggestionKind.next, label: opt);
      }
    } else {
      final partial = tokens.isEmpty ? '' : tokens.last;
      final partialLower = partial.toLowerCase();
      final prefix = line.substring(0, line.length - partial.length);
      if (tokens.length <= 1) {
        for (final cmd in commands) {
          if (cmd.toLowerCase().startsWith(partialLower) && cmd != partial) {
            add('$prefix$cmd ', SuggestionKind.command, label: cmd);
          }
        }
      } else {
        final key = tokens[tokens.length - 2];
        final options = nextWord[key] ?? nextWord[tokens.first] ?? const [];
        for (final opt in options) {
          if (opt.toLowerCase().startsWith(partialLower) && opt != partial) {
            add('$prefix$opt ', SuggestionKind.next, label: opt);
          }
        }
      }
    }

    for (final template in templates) {
      if (template.toLowerCase().startsWith(lower)) {
        add(template, SuggestionKind.command);
      }
    }

    return result;
  }
}
