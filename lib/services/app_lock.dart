import 'package:easy_localization/easy_localization.dart';
import 'package:local_auth/local_auth.dart';

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

  static Future<bool> verifyPin(String pin) async {
    final stored = await AppStore.instance.readPin();
    return stored != null && stored == pin;
  }
}
