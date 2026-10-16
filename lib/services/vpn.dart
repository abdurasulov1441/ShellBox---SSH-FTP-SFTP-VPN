import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

import '../models.dart';
import 'activity_log.dart';
import 'store.dart';

class VpnController extends ChangeNotifier {
  VpnController._();

  static final VpnController instance = VpnController._();

  static const _interfaceName = 'shellbox';

  final WireGuardFlutterInterface _wireguard = WireGuardFlutter.instance;
  bool _initialized = false;

  VpnStage _stage = VpnStage.disconnected;
  String? _activeId;
  String? _error;

  VpnStage get stage => _stage;
  String? get activeId => _activeId;
  String? get error => _error;

  bool get isConnected => _stage == VpnStage.connected;

  bool get isBusy =>
      _stage == VpnStage.connecting ||
      _stage == VpnStage.disconnecting ||
      _stage == VpnStage.waitingConnection ||
      _stage == VpnStage.authenticating ||
      _stage == VpnStage.preparing ||
      _stage == VpnStage.reconnect;

  Future<void> ensureReady() async {
    try {
      await _ensureInit();
    } catch (_) {}
  }

  Future<void> _ensureInit() async {
    if (_initialized) {
      return;
    }
    await _wireguard.initialize(interfaceName: _interfaceName);
    _wireguard.vpnStageSnapshot.listen((stage) {
      _stage = stage;
      if (stage == VpnStage.connected) {
        ActivityLog.instance.success('VPN', 'Туннель активен');
      }
      if (stage == VpnStage.disconnected || stage == VpnStage.noConnection) {
        _activeId = null;
      }
      notifyListeners();
    });
    _initialized = true;
  }

  Future<void> connect(VpnProfile profile) async {
    _error = null;
    try {
      await _ensureInit();
      final config = await AppStore.instance.readVpnConfig(profile.id);
      if (config == null || config.isEmpty) {
        _error = 'Конфигурация профиля не найдена';
        notifyListeners();
        return;
      }
      _activeId = profile.id;
      _stage = VpnStage.connecting;
      notifyListeners();
      await AppStore.instance.touchVpnProfile(profile.id);
      ActivityLog.instance.info('VPN', 'Подключение: ${profile.name}');
      await _wireguard.startVpn(
        serverAddress: profile.endpoint,
        wgQuickConfig: config,
        providerBundleIdentifier: 'uz.shellbox',
      );
    } catch (e) {
      _error = describeVpnError(e);
      _activeId = null;
      _stage = VpnStage.disconnected;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      _stage = VpnStage.disconnecting;
      notifyListeners();
      await _wireguard.stopVpn();
    } catch (e) {
      _error = describeVpnError(e);
      notifyListeners();
    }
  }

  Future<void> toggle(VpnProfile profile) async {
    if (isConnected && _activeId == profile.id) {
      await disconnect();
      return;
    }
    if (isConnected || isBusy) {
      await disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    await connect(profile);
  }
}

String describeVpnError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('denied') || text.contains('permission') || text.contains('prepare')) {
    return 'Разрешение на VPN не выдано. Разрешите подключение в системном окне.';
  }
  if (text.contains('keyformat') || text.contains('crypto')) {
    return 'Неверный ключ в конфигурации WireGuard. Проверьте PrivateKey и PublicKey в .conf';
  }
  if (text.contains('unsupported')) {
    return 'VPN не поддерживается на этой платформе';
  }
  if (text.contains('parse') || text.contains('badconfig') || text.contains('config')) {
    return 'Не удалось разобрать конфигурацию WireGuard';
  }
  return 'Ошибка VPN: $error';
}

String vpnStageLabel(VpnStage stage) {
  switch (stage) {
    case VpnStage.connected:
      return 'Подключено';
    case VpnStage.connecting:
      return 'Подключение…';
    case VpnStage.disconnecting:
      return 'Отключение…';
    case VpnStage.disconnected:
      return 'Отключено';
    case VpnStage.waitingConnection:
      return 'Ожидание соединения…';
    case VpnStage.authenticating:
      return 'Проверка…';
    case VpnStage.reconnect:
      return 'Переподключение…';
    case VpnStage.noConnection:
      return 'Нет соединения';
    case VpnStage.preparing:
      return 'Подготовка…';
    case VpnStage.denied:
      return 'Доступ запрещён';
    case VpnStage.exiting:
      return 'Завершение…';
  }
}
