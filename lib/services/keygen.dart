import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';

class GeneratedKey {
  const GeneratedKey({required this.privatePem, required this.publicLine, required this.type});

  final String privatePem;
  final String publicLine;
  final String type;
}

class KeyInfo {
  const KeyInfo({required this.type, required this.publicLine});

  final String type;
  final String publicLine;
}

class KeyGen {
  static Future<GeneratedKey> ed25519(String comment) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final seed = Uint8List.fromList(await keyPair.extractPrivateKeyBytes());
    final publicKey = Uint8List.fromList((await keyPair.extractPublicKey()).bytes);

    final keyType = utf8.encode('ssh-ed25519');
    final publicBlob = _Writer()
      ..string(keyType)
      ..string(publicKey);
    final publicBytes = publicBlob.bytes;

    final check = Random.secure().nextInt(0xFFFFFFFF);
    final privateSection = _Writer()
      ..uint32(check)
      ..uint32(check)
      ..string(keyType)
      ..string(publicKey)
      ..string(Uint8List.fromList([...seed, ...publicKey]))
      ..string(utf8.encode(comment));
    var padding = 1;
    while (privateSection.length % 8 != 0) {
      privateSection.byte(padding);
      padding++;
    }

    final file = _Writer()
      ..raw(utf8.encode('openssh-key-v1'))
      ..byte(0)
      ..string(utf8.encode('none'))
      ..string(utf8.encode('none'))
      ..string(Uint8List(0))
      ..uint32(1)
      ..string(publicBytes)
      ..string(privateSection.bytes);

    final encoded = base64.encode(file.bytes);
    final lines = <String>[];
    for (var i = 0; i < encoded.length; i += 70) {
      final end = i + 70 < encoded.length ? i + 70 : encoded.length;
      lines.add(encoded.substring(i, end));
    }
    final pem = '-----BEGIN OPENSSH PRIVATE KEY-----\n${lines.join('\n')}\n-----END OPENSSH PRIVATE KEY-----\n';
    final cleanComment = comment.trim();
    final publicLine = cleanComment.isEmpty
        ? 'ssh-ed25519 ${base64.encode(publicBytes)}'
        : 'ssh-ed25519 ${base64.encode(publicBytes)} $cleanComment';

    SSHKeyPair.fromPem(pem);

    return GeneratedKey(privatePem: pem, publicLine: publicLine, type: 'ssh-ed25519');
  }

  static bool isEncrypted(String pem) {
    try {
      return SSHKeyPair.isEncryptedPem(pem);
    } catch (_) {
      return false;
    }
  }

  static KeyInfo inspect(String pem, String? passphrase, String comment) {
    final pairs = SSHKeyPair.fromPem(pem, passphrase);
    if (pairs.isEmpty) {
      throw const FormatException('Ключ не найден в файле');
    }
    final blob = pairs.first.toPublicKey().encode();
    final type = _blobType(blob) ?? pairs.first.type;
    final cleanComment = comment.trim();
    final publicLine =
        cleanComment.isEmpty ? '$type ${base64.encode(blob)}' : '$type ${base64.encode(blob)} $cleanComment';
    return KeyInfo(type: type, publicLine: publicLine);
  }

  static String? _blobType(Uint8List blob) {
    if (blob.length < 4) {
      return null;
    }
    final length = ByteData.sublistView(blob, 0, 4).getUint32(0);
    if (length <= 0 || 4 + length > blob.length) {
      return null;
    }
    return utf8.decode(blob.sublist(4, 4 + length), allowMalformed: true);
  }
}

class _Writer {
  final BytesBuilder _builder = BytesBuilder();

  int get length => _builder.length;

  Uint8List get bytes => _builder.toBytes();

  void byte(int value) => _builder.addByte(value & 0xFF);

  void raw(List<int> data) => _builder.add(data);

  void uint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  void string(List<int> data) {
    uint32(data.length);
    _builder.add(data);
  }
}
