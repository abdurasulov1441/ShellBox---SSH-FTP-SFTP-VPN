import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models.dart';
import 'ftp_client.dart';
import 'activity_log.dart';
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
        throw ConnectError('conn.no_key_selected'.tr());
      }
      final pem = await store.readPrivateKey(keyId);
      if (pem == null || pem.isEmpty) {
        throw ConnectError('conn.key_not_in_store'.tr());
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

    ActivityLog.instance.info('SSH', 'conn.log_connecting'.tr(namedArgs: {'host': host.subtitle}));
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
    } catch (e) {
      ActivityLog.instance.error('SSH',
          'conn.log_auth_error'.tr(namedArgs: {'host': host.subtitle, 'error': describeSshError(e)}));
      client.close();
      rethrow;
    }
    ActivityLog.instance.success('SSH', 'conn.log_connected'.tr(namedArgs: {'host': host.subtitle}));

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
    return 'conn.auth_fail'.tr();
  }
  if (error is SSHAuthAbortError) {
    return 'conn.auth_abort'.tr();
  }
  if (error is SSHHostkeyError) {
    return 'conn.hostkey_rejected'.tr();
  }
  if (error is SSHKeyDecryptError) {
    return 'conn.key_decrypt'.tr();
  }
  if (error is SSHKeyDecodeError) {
    return 'conn.key_decode'.tr();
  }
  if (error is SSHHandshakeError) {
    return 'conn.handshake'.tr();
  }
  if (error is SSHChannelOpenError) {
    return 'conn.channel_open'.tr();
  }
  if (error is SSHDisconnectError) {
    return 'conn.server_closed'.tr();
  }
  if (error is SSHSocketError) {
    return 'conn.conn_lost'.tr();
  }
  if (error is SftpStatusError) {
    switch (error.code) {
      case 2:
        return 'conn.not_found'.tr();
      case 3:
        return 'conn.no_perms'.tr();
      default:
        return 'conn.sftp_error'.tr(namedArgs: {'msg': error.message});
    }
  }
  if (error is SftpError) {
    return 'conn.sftp_error'.tr(namedArgs: {'msg': error.message});
  }
  if (error is FtpException) {
    final lower = error.message.toLowerCase();
    if (error.code == 530) {
      return 'conn.ftp_auth'.tr();
    }
    if (lower.contains('resumption') || lower.contains('reuse')) {
      return 'conn.ftp_tls_reuse'.tr();
    }
    if (error.code == 550) {
      return 'conn.ftp_unavailable'.tr(namedArgs: {'msg': error.message});
    }
    if (error.code == 553 || error.code == 532) {
      return 'conn.no_perms_msg'.tr(namedArgs: {'msg': error.message});
    }
    return error.code == null
        ? 'conn.ftp_error'.tr(namedArgs: {'msg': error.message})
        : 'conn.ftp_error_code'.tr(namedArgs: {'code': '${error.code}', 'msg': error.message});
  }
  if (error is HandshakeException) {
    return 'conn.tls_error'.tr();
  }
  if (error is SocketException) {
    final message = error.osError?.message ?? error.message;
    if (message.toLowerCase().contains('refused')) {
      return 'conn.refused'.tr();
    }
    if (message.toLowerCase().contains('host lookup') || message.toLowerCase().contains('no address')) {
      return 'conn.host_not_found'.tr();
    }
    if (message.toLowerCase().contains('unreachable')) {
      return 'conn.net_unreachable'.tr();
    }
    return 'conn.connect_failed'.tr(namedArgs: {'msg': message});
  }
  if (error is TimeoutException) {
    return 'conn.timeout'.tr();
  }
  if (error is UnsupportedError) {
    return 'conn.unsupported'.tr(namedArgs: {'msg': '${error.message}'});
  }
  if (error is FormatException) {
    return 'conn.bad_format'.tr(namedArgs: {'msg': error.message});
  }
  if (error is ArgumentError) {
    return 'conn.bad_data'.tr(namedArgs: {'msg': '${error.message}'});
  }
  final text = error.toString();
  if (text.contains('passphrase')) {
    return 'conn.bad_passphrase'.tr();
  }
  return text;
}
