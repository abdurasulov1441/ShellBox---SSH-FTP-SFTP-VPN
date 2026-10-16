import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'activity_log.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String? _serverClientId = null;

  bool _initialized = false;
  bool _busy = false;
  String? _error;

  User? get user => FirebaseAuth.instance.currentUser;
  bool get signedIn => user != null;
  bool get busy => _busy;
  String? get error => _error;

  String get displayName {
    final u = user;
    if (u == null) {
      return '';
    }
    final name = u.displayName;
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    return u.email ?? 'Пользователь';
  }

  String get email => user?.email ?? '';
  String? get photoUrl => user?.photoURL;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    } catch (_) {}
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  Future<bool> signInWithGoogle() async {
    if (_busy) {
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _error = 'Вход через Google недоступен на этом устройстве';
        return false;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _error = 'Не удалось получить токен Google';
        return false;
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      ActivityLog.instance.success('Аккаунт', 'Вход через Google: $email');
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _error = 'Не удалось войти через Google';
        ActivityLog.instance.error('Аккаунт', 'Ошибка Google: ${e.code.name}');
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Ошибка авторизации';
      ActivityLog.instance.error('Аккаунт', 'Firebase: ${e.code}');
      return false;
    } catch (_) {
      _error = 'Ошибка входа';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    ActivityLog.instance.info('Аккаунт', 'Выход из аккаунта');
    notifyListeners();
  }
}
