import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';

class FtpException implements Exception {
  const FtpException(this.message, [this.code]);

  final String message;
  final int? code;

  @override
  String toString() => code == null ? message : '$code $message';
}

class FtpReply {
  const FtpReply(this.code, this.text);

  final int code;
  final String text;

  bool get positive => code >= 100 && code < 400;
  bool get preliminary => code >= 100 && code < 200;
}

class FtpItem {
  const FtpItem({
    required this.name,
    required this.isDir,
    required this.isLink,
    this.size,
    this.modified,
    this.permissions = '',
  });

  final String name;
  final bool isDir;
  final bool isLink;
  final int? size;
  final DateTime? modified;
  final String permissions;
}

class FtpClient {
  FtpClient({
    required this.host,
    this.port = 21,
    this.secure = false,
    this.timeout = const Duration(seconds: 20),
  });

  final String host;
  final int port;
  final bool secure;
  final Duration timeout;

  RawSocket? _control;
  StreamSubscription<RawSocketEvent>? _subscription;
  final List<int> _buffer = [];
  final List<String> _lines = [];
  Completer<void>? _lineWaiter;
  Object? _controlError;
  bool _closed = false;
  bool _mlsd = false;

  static bool _acceptCertificate(X509Certificate certificate) => true;

  Future<void> connect(String user, String password) async {
    final socket = await RawSocket.connect(host, port, timeout: timeout);
    _attach(socket);
    final greeting = await _readReply();
    if (greeting.code != 220) {
      throw FtpException(greeting.text, greeting.code);
    }
    if (secure) {
      final auth = await _command('AUTH TLS');
      if (auth.code != 234) {
        throw FtpException('conn.ftp_no_ftps'.tr(namedArgs: {'text': auth.text}), auth.code);
      }
      final subscription = _subscription;
      _subscription = null;
      final secured = await RawSecureSocket.secure(
        socket,
        subscription: subscription,
        host: host,
        onBadCertificate: _acceptCertificate,
      );
      _attach(secured);
      await _expect('PBSZ 0', const {200});
      await _expect('PROT P', const {200});
    }
    final userReply = await _command('USER $user');
    if (userReply.code == 331 || userReply.code == 332) {
      final passReply = await _command('PASS $password');
      if (passReply.code != 230 && passReply.code != 202) {
        throw FtpException('conn.login_error'.tr(namedArgs: {'text': passReply.text}), passReply.code);
      }
    } else if (userReply.code != 230) {
      throw FtpException('conn.login_error'.tr(namedArgs: {'text': userReply.text}), userReply.code);
    }
    final features = await _command('FEAT');
    if (features.code == 211) {
      final upper = features.text.toUpperCase();
      _mlsd = upper.contains('MLSD') || upper.contains('MLST');
      if (upper.contains('UTF8')) {
        await _command('OPTS UTF8 ON');
      }
    }
    await _expect('TYPE I', const {200});
  }

  void _attach(RawSocket socket) {
    _control = socket;
    _subscription = socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final data = socket.read();
          if (data != null && data.isNotEmpty) {
            _buffer.addAll(data);
            _splitLines();
          }
        } else if (event == RawSocketEvent.readClosed || event == RawSocketEvent.closed) {
          _closed = true;
          _wake();
        }
      },
      onError: (Object error) {
        _controlError = error;
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
      cancelOnError: true,
    );
  }

  void _splitLines() {
    while (true) {
      final index = _buffer.indexOf(10);
      if (index < 0) {
        break;
      }
      var line = utf8.decode(_buffer.sublist(0, index), allowMalformed: true);
      _buffer.removeRange(0, index + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      _lines.add(line);
    }
    _wake();
  }

  void _write(List<int> bytes) {
    final socket = _control;
    if (socket == null) {
      throw FtpException('conn.no_connection'.tr());
    }
    var offset = 0;
    var attempts = 0;
    while (offset < bytes.length) {
      final written = socket.write(bytes, offset);
      offset += written;
      if (written == 0) {
        attempts++;
        if (attempts > 100000) {
          throw FtpException('conn.send_failed'.tr());
        }
      }
    }
  }

  void _wake() {
    final waiter = _lineWaiter;
    _lineWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<String> _nextLine() async {
    while (_lines.isEmpty) {
      final error = _controlError;
      if (error != null) {
        throw error;
      }
      if (_closed) {
        throw FtpException('conn.server_closed'.tr());
      }
      final waiter = Completer<void>();
      _lineWaiter = waiter;
      await waiter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('conn.ftp_no_response'.tr(), timeout),
      );
    }
    return _lines.removeAt(0);
  }

  Future<FtpReply> _readReply() async {
    final first = await _nextLine();
    if (first.length < 3) {
      return _readReply();
    }
    final code = int.tryParse(first.substring(0, 3));
    if (code == null) {
      return _readReply();
    }
    final buffer = StringBuffer(first.length > 4 ? first.substring(4) : '');
    if (first.length > 3 && first[3] == '-') {
      while (true) {
        final line = await _nextLine();
        buffer.write('\n');
        if (line.startsWith('$code ')) {
          buffer.write(line.substring(4));
          break;
        }
        buffer.write(line);
      }
    }
    return FtpReply(code, buffer.toString().trim());
  }

  void _send(String command) => _write(utf8.encode('$command\r\n'));

  Future<FtpReply> _command(String command) async {
    _send(command);
    return _readReply();
  }

  Future<FtpReply> _expect(String command, Set<int> codes) async {
    final reply = await _command(command);
    if (!codes.contains(reply.code)) {
      throw FtpException(reply.text, reply.code);
    }
    return reply;
  }

  Future<Socket> _openPassive() async {
    final epsv = await _command('EPSV');
    int? dataPort;
    if (epsv.code == 229) {
      final match = RegExp(r'\(\s*(.)\1\1(\d+)\1\s*\)').firstMatch(epsv.text);
      if (match != null) {
        dataPort = int.tryParse(match.group(2)!);
      }
    }
    if (dataPort == null) {
      final pasv = await _expect('PASV', const {227});
      final match = RegExp(r'(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)').firstMatch(pasv.text);
      if (match == null) {
        throw FtpException('conn.pasv_parse'.tr(namedArgs: {'text': pasv.text}));
      }
      dataPort = int.parse(match.group(5)!) * 256 + int.parse(match.group(6)!);
    }
    return Socket.connect(host, dataPort, timeout: timeout);
  }

  Future<T> _transfer<T>(String command, Future<T> Function(Socket data) body) async {
    final raw = await _openPassive();
    Socket? data;
    try {
      _send(command);
      final securing = secure
          ? SecureSocket.secure(raw, host: host, onBadCertificate: _acceptCertificate)
          : Future<Socket>.value(raw);
      final start = await _readReply();
      if (!start.preliminary) {
        raw.destroy();
        unawaited(securing.then((s) => s.destroy(), onError: (_) {}));
        throw FtpException(start.text, start.code);
      }
      data = await securing;
      final result = await body(data);
      data.destroy();
      final end = await _readReply();
      if (end.code != 226 && end.code != 250) {
        throw FtpException(end.text, end.code);
      }
      return result;
    } catch (_) {
      data?.destroy();
      raw.destroy();
      rethrow;
    }
  }

  Future<String> pwd() async {
    final reply = await _expect('PWD', const {257});
    final start = reply.text.indexOf('"');
    final end = reply.text.lastIndexOf('"');
    if (start < 0 || end <= start) {
      return '/';
    }
    final path = reply.text.substring(start + 1, end).replaceAll('""', '"').replaceAll(r'\', '/');
    return path.isEmpty ? '/' : path;
  }

  Future<void> cwd(String path) => _expect('CWD $path', const {200, 250});

  Future<List<FtpItem>> list(String path) async {
    await cwd(path);
    if (_mlsd) {
      try {
        final raw = await _readAll('MLSD');
        return _parseMlsd(raw);
      } on FtpException catch (e) {
        if (e.code == null || e.code! < 500) {
          rethrow;
        }
        _mlsd = false;
      }
    }
    final raw = await _readAll('LIST -a');
    final items = _parseList(raw);
    if (items.isEmpty && raw.trim().isNotEmpty) {
      return _parseList(await _readAll('LIST'));
    }
    return items;
  }

  Future<String> _readAll(String command) {
    return _transfer(command, (data) async {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in data) {
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    });
  }

  Future<void> download(String remotePath, IOSink sink) {
    return _transfer('RETR $remotePath', (data) async {
      await sink.addStream(data);
    });
  }

  Future<void> upload(String remotePath, Stream<List<int>> source) {
    return _transfer('STOR $remotePath', (data) async {
      await data.addStream(source);
      await data.flush();
      await data.close();
      await data.drain<void>().timeout(timeout, onTimeout: () {});
    });
  }

  Future<void> mkdir(String path) => _expect('MKD $path', const {257, 250});

  Future<void> rmdir(String path) => _expect('RMD $path', const {250});

  Future<void> delete(String path) => _expect('DELE $path', const {250});

  Future<void> rename(String from, String to) async {
    await _expect('RNFR $from', const {350});
    await _expect('RNTO $to', const {250});
  }

  Future<void> close() async {
    final socket = _control;
    _control = null;
    if (socket == null) {
      return;
    }
    try {
      socket.write(utf8.encode('QUIT\r\n'));
    } catch (_) {}
    await _subscription?.cancel();
    _subscription = null;
    try {
      await socket.close();
    } catch (_) {}
  }

  List<FtpItem> _parseMlsd(String raw) {
    final items = <FtpItem>[];
    for (final line in const LineSplitter().convert(raw)) {
      final space = line.indexOf(' ');
      if (space <= 0) {
        continue;
      }
      final name = line.substring(space + 1);
      final facts = <String, String>{};
      for (final fact in line.substring(0, space).split(';')) {
        final eq = fact.indexOf('=');
        if (eq > 0) {
          facts[fact.substring(0, eq).toLowerCase()] = fact.substring(eq + 1);
        }
      }
      final type = (facts['type'] ?? '').toLowerCase();
      if (type == 'cdir' || type == 'pdir' || name == '.' || name == '..') {
        continue;
      }
      final isLink = type.contains('symlink') || type.startsWith('os.unix=slink');
      final mode = facts['unix.mode'];
      items.add(
        FtpItem(
          name: name,
          isDir: type == 'dir',
          isLink: isLink,
          size: int.tryParse(facts['size'] ?? ''),
          modified: _parseMlsdTime(facts['modify']),
          permissions: mode == null ? '' : _modeString(mode, type == 'dir', isLink),
        ),
      );
    }
    return items;
  }

  DateTime? _parseMlsdTime(String? value) {
    if (value == null || value.length < 14) {
      return null;
    }
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    final hour = int.tryParse(value.substring(8, 10));
    final minute = int.tryParse(value.substring(10, 12));
    final second = int.tryParse(value.substring(12, 14));
    if (year == null || month == null || day == null || hour == null || minute == null || second == null) {
      return null;
    }
    return DateTime.utc(year, month, day, hour, minute, second).toLocal();
  }

  String _modeString(String octal, bool isDir, bool isLink) {
    final value = int.tryParse(octal, radix: 8);
    if (value == null) {
      return '';
    }
    const flags = 'rwxrwxrwx';
    final buffer = StringBuffer(isLink ? 'l' : (isDir ? 'd' : '-'));
    for (var i = 0; i < 9; i++) {
      buffer.write((value >> (8 - i)) & 1 == 1 ? flags[i] : '-');
    }
    return buffer.toString();
  }

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final _unixLine = RegExp(
    r'^([\-dlbcps])([rwxsStT\-]{9})\S*\s+\d+\s+\S+\s+(?:\S+\s+)?(\d+)\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{1,2}:\d{2}|\d{4})\s+(.+)$',
  );

  static final _windowsLine =
      RegExp(r'^(\d{2})-(\d{2})-(\d{2,4})\s+(\d{1,2}):(\d{2})([AaPp][Mm])?\s+(<DIR>|\d+)\s+(.+)$');

  List<FtpItem> _parseList(String raw) {
    final items = <FtpItem>[];
    final now = DateTime.now();
    for (final line in const LineSplitter().convert(raw)) {
      final unix = _unixLine.firstMatch(line);
      if (unix != null) {
        final kind = unix.group(1)!;
        var name = unix.group(7)!;
        final isLink = kind == 'l';
        if (isLink) {
          final arrow = name.indexOf(' -> ');
          if (arrow > 0) {
            name = name.substring(0, arrow);
          }
        }
        if (name == '.' || name == '..') {
          continue;
        }
        final month = _months[unix.group(4)!.toLowerCase()] ?? 1;
        final day = int.tryParse(unix.group(5)!) ?? 1;
        final timeOrYear = unix.group(6)!;
        DateTime? modified;
        if (timeOrYear.contains(':')) {
          final parts = timeOrYear.split(':');
          modified = DateTime(now.year, month, day, int.parse(parts[0]), int.parse(parts[1]));
          if (modified.isAfter(now.add(const Duration(days: 1)))) {
            modified = DateTime(now.year - 1, month, day, int.parse(parts[0]), int.parse(parts[1]));
          }
        } else {
          modified = DateTime(int.parse(timeOrYear), month, day);
        }
        items.add(
          FtpItem(
            name: name,
            isDir: kind == 'd',
            isLink: isLink,
            size: int.tryParse(unix.group(3)!),
            modified: modified,
            permissions: '$kind${unix.group(2)!}',
          ),
        );
        continue;
      }
      final windows = _windowsLine.firstMatch(line);
      if (windows != null) {
        final name = windows.group(8)!;
        if (name == '.' || name == '..') {
          continue;
        }
        var year = int.parse(windows.group(3)!);
        if (year < 100) {
          year += year < 70 ? 2000 : 1900;
        }
        var hour = int.parse(windows.group(4)!);
        final meridiem = windows.group(6)?.toLowerCase();
        if (meridiem == 'pm' && hour < 12) {
          hour += 12;
        }
        if (meridiem == 'am' && hour == 12) {
          hour = 0;
        }
        final isDir = windows.group(7) == '<DIR>';
        items.add(
          FtpItem(
            name: name,
            isDir: isDir,
            isLink: false,
            size: isDir ? null : int.tryParse(windows.group(7)!),
            modified: DateTime(
              year,
              int.parse(windows.group(1)!),
              int.parse(windows.group(2)!),
              hour,
              int.parse(windows.group(5)!),
            ),
          ),
        );
      }
    }
    return items;
  }
}
