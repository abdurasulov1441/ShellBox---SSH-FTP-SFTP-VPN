import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models.dart';
import 'ftp_client.dart';
import 'store.dart';

class HostKeyCheck {
  const HostKeyCheck({
    required this.host,
    required this.type,
    required this.fingerprint,
    this.previous,
  });

  final Host host;
  final String type;
  final String fingerprint;
  final String? previous;

  String get value => '$type $fingerprint';

  bool get changed => previous != null;
}

class PasswordReply {
  const PasswordReply(this.password, {this.remember = false});

  final String password;
  final bool remember;
}

class ConnectError implements Exception {
  const ConnectError(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef HostKeyPrompt = Future<bool> Function(HostKeyCheck check);
typedef PasswordPrompt = Future<PasswordReply?> Function(Host host);

class SshConnector {
  static const legacyAlgorithms = SSHAlgorithms(
    kex: [
      SSHKexType.x25519Rfc,
      SSHKexType.x25519,
      SSHKexType.nistp521,
      SSHKexType.nistp384,
      SSHKexType.nistp256,
      SSHKexType.dhGexSha256,
      SSHKexType.dh14Sha256,
      SSHKexType.dhGexSha1,
      SSHKexType.dh14Sha1,
      SSHKexType.dh1Sha1,
    ],
    hostkey: [
      SSHHostkeyType.ed25519,
      SSHHostkeyType.rsaSha512,
      SSHHostkeyType.rsaSha256,
      SSHHostkeyType.ecdsa521,
      SSHHostkeyType.ecdsa384,
      SSHHostkeyType.ecdsa256,
      SSHHostkeyType.rsaSha1,
    ],
    cipher: [
      SSHCipherType.aes256gcm,
      SSHCipherType.aes128gcm,
      SSHCipherType.chacha20poly1305,
      SSHCipherType.aes256ctr,
      SSHCipherType.aes192ctr,
      SSHCipherType.aes128ctr,
      SSHCipherType.aes256cbc,
      SSHCipherType.aes192cbc,
      SSHCipherType.aes128cbc,
    ],
    mac: [
      SSHMacType.hmacSha256Etm,
      SSHMacType.hmacSha512Etm,
      SSHMacType.hmacSha256,
      SSHMacType.hmacSha512,
      SSHMacType.hmacSha1,
      SSHMacType.hmacMd5,
    ],
  );

  static Future<SSHClient> connect(
    Host host, {
    required HostKeyPrompt onHostKey,
    required PasswordPrompt onPassword,
  }) async {
    final store = AppStore.instance;
    List<SSHIdentity>? identities;
    if (host.auth == AuthType.key) {
      final keyId = host.keyId;
      if (keyId == null || store.keyById(keyId) == null) {
        throw const ConnectError('Для хоста не выбран SSH-ключ');
      }
      final pem = await store.readPrivateKey(keyId);
      if (pem == null || pem.isEmpty) {
        throw const ConnectError('Приватный ключ не найден в хранилище');
      }
      final passphrase = await store.readPassphrase(keyId);
      identities = SSHKeyPair.fromPem(pem, passphrase == null || passphrase.isEmpty ? null : passphrase);
    }

    String? storedPassword;
    if (host.auth == AuthType.password) {
      storedPassword = await store.readPassword(host.id);
    }
    var storedUsed = false;
    PasswordReply? lastReply;

    Future<String?> requestPassword() async {
      final stored = storedPassword;
      if (!storedUsed && stored != null && stored.isNotEmpty) {
        storedUsed = true;
        return stored;
      }
      storedUsed = true;
      final reply = await onPassword(host);
      lastReply = reply;
      return reply?.password;
    }

    final socket = await SSHSocket.connect(host.address, host.port, timeout: const Duration(seconds: 12));

    final client = SSHClient(
      socket,
      username: host.username,
      identities: identities,
      algorithms: host.legacy ? legacyAlgorithms : const SSHAlgorithms(),
      keepAliveInterval: const Duration(seconds: 20),
      onPasswordRequest: requestPassword,
      onUserInfoRequest: (request) async {
        if (request.prompts.isEmpty) {
          return <String>[];
        }
        final answers = <String>[];
        for (final prompt in request.prompts) {
          if (prompt.echo) {
            answers.add('');
            continue;
          }
          final password = await requestPassword();
          if (password == null) {
            return null;
          }
          answers.add(password);
        }
        return answers;
      },
      onVerifyHostKey: (String type, Uint8List fingerprint) async {
        final check = HostKeyCheck(
          host: host,
          type: type,
          fingerprint: utf8.decode(fingerprint, allowMalformed: true),
          previous: store.knownHosts[host.endpoint],
        );
        if (check.previous == check.value) {
          return true;
        }
        final accepted = await onHostKey(check);
        if (accepted) {
          await store.trustHostKey(host.endpoint, check.value);
        }
        return accepted;
      },
    );

    try {
      await client.authenticated;
    } catch (_) {
      client.close();
      rethrow;
    }

    final reply = lastReply;
    if (reply != null && reply.remember && store.hostById(host.id) != null) {
      await store.savePassword(host.id, reply.password);
    }
    return client;
  }
}

String describeSshError(Object error) {
  if (error is ConnectError) {
    return error.message;
  }
  if (error is SSHAuthFailError) {
    return 'Ошибка входа: неверный логин, пароль или ключ';
  }
  if (error is SSHAuthAbortError) {
    return 'Вход отменён или сервер не принял ни один способ входа';
  }
  if (error is SSHHostkeyError) {
    return 'Ключ сервера отклонён — соединение прервано';
  }
  if (error is SSHKeyDecryptError) {
    return 'Не удалось расшифровать ключ: неверная парольная фраза';
  }
  if (error is SSHKeyDecodeError) {
    return 'Не удалось прочитать SSH-ключ: формат не поддерживается';
  }
  if (error is SSHHandshakeError) {
    return 'Не удалось согласовать алгоритмы шифрования. Попробуйте включить «Старые алгоритмы» в настройках хоста';
  }
  if (error is SSHChannelOpenError) {
    return 'Сервер отказал в открытии канала';
  }
  if (error is SSHDisconnectError) {
    return 'Сервер закрыл соединение';
  }
  if (error is SSHSocketError) {
    return 'Соединение разорвано';
  }
  if (error is SftpStatusError) {
    switch (error.code) {
      case 2:
        return 'Файл или папка не найдены';
      case 3:
        return 'Недостаточно прав';
      default:
        return 'Ошибка SFTP: ${error.message}';
    }
  }
  if (error is SftpError) {
    return 'Ошибка SFTP: ${error.message}';
  }
  if (error is FtpException) {
    final lower = error.message.toLowerCase();
    if (error.code == 530) {
      return 'Ошибка входа FTP: неверный логин или пароль';
    }
    if (lower.contains('resumption') || lower.contains('reuse')) {
      return 'Сервер требует повторного использования TLS-сессии для передачи данных — это пока не поддерживается. Используйте SFTP или отключите это требование на сервере (vsftpd: require_ssl_reuse=NO)';
    }
    if (error.code == 550) {
      return 'Файл или папка недоступны: ${error.message}';
    }
    if (error.code == 553 || error.code == 532) {
      return 'Недостаточно прав: ${error.message}';
    }
    return error.code == null ? 'Ошибка FTP: ${error.message}' : 'Ошибка FTP ${error.code}: ${error.message}';
  }
  if (error is HandshakeException) {
    return 'Ошибка TLS: сервер не поддерживает защищённое соединение или сертификат недействителен';
  }
  if (error is SocketException) {
    final message = error.osError?.message ?? error.message;
    if (message.toLowerCase().contains('refused')) {
      return 'Сервер отклонил подключение (порт закрыт)';
    }
    if (message.toLowerCase().contains('host lookup') || message.toLowerCase().contains('no address')) {
      return 'Не удалось найти сервер по адресу';
    }
    if (message.toLowerCase().contains('unreachable')) {
      return 'Сеть недоступна';
    }
    return 'Не удалось подключиться к серверу: $message';
  }
  if (error is TimeoutException) {
    return 'Превышено время ожидания ответа сервера';
  }
  if (error is UnsupportedError) {
    return 'Не поддерживается: ${error.message}';
  }
  if (error is FormatException) {
    return 'Неверный формат: ${error.message}';
  }
  if (error is ArgumentError) {
    return 'Неверные данные: ${error.message}';
  }
  final text = error.toString();
  if (text.contains('passphrase')) {
    return 'Неверная или отсутствующая парольная фраза ключа';
  }
  return text;
}
