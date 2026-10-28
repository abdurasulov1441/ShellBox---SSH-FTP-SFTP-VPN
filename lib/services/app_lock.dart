import 'package:easy_localization/easy_localization.dart';
import 'package:local_auth/local_auth.dart';

import 'pin_hasher.dart';
import 'store.dart';

class AppLock {
  static final LocalAuthentication _auth = LocalAuthentication();

  static bool get isEnabled => AppStore.instance.lockEnabled;
  static bool get biometricEnabled => AppStore.instance.biometricEnabled;

  static Future<bool> biometricAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'lock.biometric_reason'.tr(),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Time left before the next PIN attempt is allowed, or null if not locked.
  static Duration? lockoutRemaining() {
    final until = AppStore.instance.pinLockedUntil;
    if (until == null) {
      return null;
    }
    final left = until.difference(DateTime.now());
    return left > Duration.zero ? left : null;
  }

  static Future<PinResult> verifyPin(String pin) async {
    final store = AppStore.instance;
    final locked = lockoutRemaining();
    if (locked != null) {
      return PinLocked(locked);
    }
    final stored = await store.readPin();
    if (stored == null || !await PinHasher.verify(pin, stored)) {
      await store.recordPinFailure();
      final after = lockoutRemaining();
      return after == null ? const PinWrong() : PinLocked(after);
    }
    await store.resetPinFailures();
    if (!PinHasher.isHashed(stored)) {
      await store.savePinHash(await PinHasher.hash(pin));
    }
    return const PinOk();
  }
}

sealed class PinResult {
  const PinResult();
}

final class PinOk extends PinResult {
  const PinOk();
}

final class PinWrong extends PinResult {
  const PinWrong();
}

final class PinLocked extends PinResult {
  const PinLocked(this.remaining);

  final Duration remaining;
}
