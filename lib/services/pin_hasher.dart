import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Salted PBKDF2-HMAC-SHA256 hashing for the app-lock PIN.
///
/// Stored format: `pbkdf2$<iterations>$<salt b64>$<hash b64>`.
/// Values without the prefix are legacy plaintext PINs from older builds.
class PinHasher {
  static const _prefix = 'pbkdf2';
  static const defaultIterations = 60000;
  static const _saltLength = 16;
  static const _hashBits = 256;

  static final _random = Random.secure();

  static bool isHashed(String stored) => stored.startsWith('$_prefix\$');

  static Future<String> hash(String pin, {int iterations = defaultIterations, List<int>? salt}) async {
    final saltBytes = salt ?? List<int>.generate(_saltLength, (_) => _random.nextInt(256));
    final digest = await _derive(pin, saltBytes, iterations);
    return [_prefix, '$iterations', base64.encode(saltBytes), base64.encode(digest)].join(r'$');
  }

  static Future<bool> verify(String pin, String stored) async {
    if (!isHashed(stored)) {
      return _constantTimeEquals(utf8.encode(pin), utf8.encode(stored));
    }
    final parts = stored.split(r'$');
    if (parts.length != 4) {
      return false;
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) {
      return false;
    }
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = await _derive(pin, salt, iterations);
    return _constantTimeEquals(actual, expected);
  }

  static Future<List<int>> _derive(String pin, List<int> salt, int iterations) async {
    final algorithm = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: _hashBits);
    final key = await algorithm.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Lockout schedule after repeated wrong PIN entries.
class PinThrottle {
  static const freeAttempts = 5;
  static const baseDelay = Duration(seconds: 30);
  static const maxDelay = Duration(hours: 1);

  /// How long input is blocked after [failures] consecutive wrong PINs.
  static Duration delayAfter(int failures) {
    if (failures < freeAttempts) {
      return Duration.zero;
    }
    final steps = min(failures - freeAttempts, 10);
    final seconds = baseDelay.inSeconds * (1 << steps);
    return seconds >= maxDelay.inSeconds ? maxDelay : Duration(seconds: seconds);
  }
}
