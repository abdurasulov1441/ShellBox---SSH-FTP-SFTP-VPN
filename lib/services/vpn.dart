import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
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
        ActivityLog.instance.success('VPN', 'vpn.log_tunnel_active'.tr());
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
        _error = 'vpn.config_not_found'.tr();
        notifyListeners();
        return;
      }
      _activeId = profile.id;
      _stage = VpnStage.connecting;
      notifyListeners();
      await AppStore.instance.touchVpnProfile(profile.id);
      ActivityLog.instance.info('VPN', 'vpn.log_connecting'.tr(namedArgs: {'name': profile.name}));
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
    return 'vpn.err_permission'.tr();
  }
  if (text.contains('keyformat') || text.contains('crypto')) {
    return 'vpn.err_key'.tr();
  }
  if (text.contains('unsupported')) {
    return 'vpn.err_unsupported'.tr();
  }
  if (text.contains('parse') || text.contains('badconfig') || text.contains('config')) {
    return 'vpn.err_parse'.tr();
  }
  return 'vpn.err_generic'.tr(namedArgs: {'error': '$error'});
}

String vpnStageLabel(VpnStage stage) {
  switch (stage) {
    case VpnStage.connected:
      return 'vpn.stage_connected'.tr();
    case VpnStage.connecting:
      return 'vpn.stage_connecting'.tr();
    case VpnStage.disconnecting:
      return 'vpn.stage_disconnecting'.tr();
    case VpnStage.disconnected:
      return 'vpn.stage_disconnected'.tr();
    case VpnStage.waitingConnection:
      return 'vpn.stage_waiting'.tr();
    case VpnStage.authenticating:
      return 'vpn.stage_auth'.tr();
    case VpnStage.reconnect:
      return 'vpn.stage_reconnect'.tr();
    case VpnStage.noConnection:
      return 'vpn.stage_no_conn'.tr();
    case VpnStage.preparing:
      return 'vpn.stage_preparing'.tr();
    case VpnStage.denied:
      return 'vpn.stage_denied'.tr();
    case VpnStage.exiting:
      return 'vpn.stage_exiting'.tr();
  }
}
