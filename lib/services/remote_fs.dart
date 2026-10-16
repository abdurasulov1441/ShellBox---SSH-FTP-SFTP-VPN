import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';

import '../models.dart';
import '../widgets/dialogs.dart';
import 'connector.dart';
import 'ftp_client.dart';
import 'store.dart';

class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.isLink,
    required this.size,
    required this.modified,
    required this.permissions,
  });

  final String name;
  final String path;
  final bool isDir;
  final bool isLink;
  final int? size;
  final DateTime? modified;
  final String permissions;

  bool get hidden => name.startsWith('.');
}

String joinRemote(String dir, String name) => dir == '/' ? '/$name' : '$dir/$name';

String parentRemote(String path) {
  if (path == '/' || path.isEmpty) {
    return '/';
  }
  final index = path.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return path.substring(0, index);
}

void sortEntries(List<RemoteEntry> entries) {
  entries.sort((a, b) {
    final aDir = a.isDir ? 0 : 1;
    final bDir = b.isDir ? 0 : 1;
    if (aDir != bDir) {
      return aDir - bDir;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

abstract class RemoteFs {
  String get kind;

  Future<String> connect();

  Future<List<RemoteEntry>> list(String path);

  Future<void> download(String remotePath, File target);

  Future<void> upload(PlatformFile file, String remotePath);

  Future<void> mkdir(String path);

  Future<void> rename(String from, String to);

  Future<void> removeFile(String path);

  Future<void> removeEmptyDir(String path);

  Future<void> close();

  static RemoteFs forHost(Host host) => host.protocol.isFtp ? FtpFs(host) : SftpFs(host);
}

class SftpFs implements RemoteFs {
  SftpFs(this.host);

  final Host host;
  SSHClient? _client;
  SftpClient? _sftp;

  @override
  String get kind => 'SFTP';

  SftpClient get _requireSftp {
    final sftp = _sftp;
    if (sftp == null) {
      throw const ConnectError('Нет подключения');
    }
    return sftp;
  }

  @override
  Future<String> connect() async {
    final client = await SshConnector.connect(host, onHostKey: confirmHostKey, onPassword: askPassword);
    _client = client;
    final sftp = await client.sftp();
    _sftp = sftp;
    final home = await sftp.absolute('.');
    unawaited(AppStore.instance.touchHost(host.id));
    return home.isEmpty ? '/' : home;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final names = await _requireSftp.listdir(path);
    final entries = <RemoteEntry>[];
    for (final item in names) {
      if (item.filename == '.' || item.filename == '..') {
        continue;
      }
      final long = item.longname;
      final first = long.isNotEmpty ? long[0] : '';
      final permissionToken = long.split(RegExp(r'\s+')).first;
      final mtime = item.attr.modifyTime;
      entries.add(
        RemoteEntry(
          name: item.filename,
          path: joinRemote(path, item.filename),
          isDir: first.isNotEmpty ? first == 'd' : item.attr.isDirectory,
          isLink: first.isNotEmpty ? first == 'l' : item.attr.isSymbolicLink,
          size: item.attr.size,
          modified: mtime == null ? null : DateTime.fromMillisecondsSinceEpoch(mtime * 1000),
          permissions: permissionToken.length == 10 ? permissionToken : '',
        ),
      );
    }
    sortEntries(entries);
    return entries;
  }

  @override
  Future<void> download(String remotePath, File target) async {
    final sink = target.openWrite();
    try {
      await _requireSftp.download(remotePath, sink);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> upload(PlatformFile file, String remotePath) async {
    final remote = await _requireSftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
    try {
      await remote.write(file.readAsByteStream()).done;
    } finally {
      await remote.close();
    }
  }

  @override
  Future<void> mkdir(String path) => _requireSftp.mkdir(path);

  @override
  Future<void> rename(String from, String to) => _requireSftp.rename(from, to);

  @override
  Future<void> removeFile(String path) => _requireSftp.remove(path);

  @override
  Future<void> removeEmptyDir(String path) => _requireSftp.rmdir(path);

  @override
  Future<void> close() async {
    final sftp = _sftp;
    _sftp = null;
    if (sftp != null) {
      try {
        await sftp.close();
      } catch (_) {}
    }
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        client.close();
      } catch (_) {}
    }
  }
}

class FtpFs implements RemoteFs {
  FtpFs(this.host);

  final Host host;
  FtpClient? _ftp;
  Future<void> _queue = Future.value();

  @override
  String get kind => host.protocol == Protocol.ftps ? 'FTPS' : 'FTP';

  FtpClient get _requireFtp {
    final ftp = _ftp;
    if (ftp == null) {
      throw const ConnectError('Нет подключения');
    }
    return ftp;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }

  bool get _anonymous {
    final user = host.username.trim().toLowerCase();
    return user.isEmpty || user == 'anonymous' || user == 'ftp';
  }

  @override
  Future<String> connect() async {
    var password = '';
    PasswordReply? reply;
    if (!_anonymous) {
      final stored = await AppStore.instance.readPassword(host.id);
      if (stored != null && stored.isNotEmpty) {
        password = stored;
      } else {
        reply = await askPassword(host);
        if (reply == null) {
          throw const ConnectError('Вход отменён');
        }
        password = reply.password;
      }
    }
    final ftp = FtpClient(host: host.address, port: host.port, secure: host.protocol == Protocol.ftps);
    try {
      await ftp.connect(_anonymous ? 'anonymous' : host.username.trim(), _anonymous ? 'anonymous@shellbox' : password);
    } catch (_) {
      await ftp.close();
      rethrow;
    }
    _ftp = ftp;
    if (reply != null && reply.remember && AppStore.instance.hostById(host.id) != null) {
      await AppStore.instance.savePassword(host.id, password);
    }
    unawaited(AppStore.instance.touchHost(host.id));
    final current = await ftp.pwd();
    return current.isEmpty ? '/' : current;
  }

  @override
  Future<List<RemoteEntry>> list(String path) => _serial(() async {
        final items = await _requireFtp.list(path);
        final entries = [
          for (final item in items)
            RemoteEntry(
              name: item.name,
              path: joinRemote(path, item.name),
              isDir: item.isDir,
              isLink: item.isLink,
              size: item.size,
              modified: item.modified,
              permissions: item.permissions,
            ),
        ];
        sortEntries(entries);
        return entries;
      });

  @override
  Future<void> download(String remotePath, File target) => _serial(() async {
        final sink = target.openWrite();
        try {
          await _requireFtp.download(remotePath, sink);
          await sink.flush();
        } finally {
          await sink.close();
        }
      });

  @override
  Future<void> upload(PlatformFile file, String remotePath) =>
      _serial(() => _requireFtp.upload(remotePath, file.readAsByteStream()));

  @override
  Future<void> mkdir(String path) => _serial(() => _requireFtp.mkdir(path));

  @override
  Future<void> rename(String from, String to) => _serial(() => _requireFtp.rename(from, to));

  @override
  Future<void> removeFile(String path) => _serial(() => _requireFtp.delete(path));

  @override
  Future<void> removeEmptyDir(String path) => _serial(() => _requireFtp.rmdir(path));

  @override
  Future<void> close() async {
    final ftp = _ftp;
    _ftp = null;
    if (ftp != null) {
      await ftp.close();
    }
  }
}
