import 'dart:convert';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'pin_hasher.dart';
import 'stored_json.dart';

class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  static const _hostsKey = 'hosts';
  static const _keysKey = 'keys';
  static const _snippetsKey = 'snippets';
  static const _knownHostsKey = 'known_hosts';
  static const _fontSizeKey = 'font_size';
  static const _terminalThemeKey = 'terminal_theme';
  static const _terminalFontKey = 'terminal_font';
  static const _themeModeKey = 'theme_mode';
  static const _lockEnabledKey = 'lock_enabled';
  static const _biometricKey = 'biometric_enabled';
  static const _vpnKey = 'vpn_profiles';
  static const _wolKey = 'wol_devices';
  static const _secureScreenKey = 'secure_screen';
  static const _pinFailuresKey = 'pin_failures';
  static const _pinLockedUntilKey = 'pin_locked_until';
  static const _pinKey = 'app_pin';

  static final _random = Random.secure();

  static String newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = List.generate(6, (_) => _random.nextInt(36).toRadixString(36)).join();
    return '$time$noise';
  }

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  late SharedPreferences _prefs;

  List<Host> _hosts = [];
  List<SshKey> _keys = [];
  List<Snippet> _snippets = [];
  List<VpnProfile> _vpnProfiles = [];
  List<WolDevice> _wolDevices = [];
  Map<String, String> _knownHosts = {};
  double _fontSize = 14;
  String _terminalTheme = 'midnight';
  String _terminalFont = 'jetbrains';
  String _themeMode = 'system';
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _secureScreen = true;
  final List<String> _commandHistory = [];
  final List<String> _corruptKeys = [];

  List<Host> get hosts => List.unmodifiable(_hosts);
  List<SshKey> get keys => List.unmodifiable(_keys);
  List<Snippet> get snippets => List.unmodifiable(_snippets);
  List<VpnProfile> get vpnProfiles => List.unmodifiable(_vpnProfiles);
  List<WolDevice> get wolDevices => List.unmodifiable(_wolDevices);
  Map<String, String> get knownHosts => Map.unmodifiable(_knownHosts);
  double get fontSize => _fontSize;
  String get terminalTheme => _terminalTheme;
  String get terminalFont => _terminalFont;
  String get themeMode => _themeMode;
  bool get lockEnabled => _lockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get secureScreen => _secureScreen;

  /// Storage keys whose data could not be read on the last [load]; the raw
  /// value was backed up under `<key>.corrupt.<timestamp>`.
  List<String> get corruptKeys => List.unmodifiable(_corruptKeys);

  List<String> get commandHistory => _commandHistory.reversed.toList(growable: false);

  void addCommandHistory(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty || trimmed.length > 200) {
      return;
    }
    _commandHistory.remove(trimmed);
    _commandHistory.add(trimmed);
    if (_commandHistory.length > 200) {
      _commandHistory.removeRange(0, _commandHistory.length - 200);
    }
  }

  List<String> get groups {
    final result = _hosts.map((h) => h.group.trim()).where((g) => g.isNotEmpty).toSet().toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  List<Host> get recentHosts {
    final used = _hosts.where((h) => h.lastUsed != null).toList();
    used.sort((a, b) => b.lastUsed!.compareTo(a.lastUsed!));
    return used.length > 8 ? used.sublist(0, 8) : used;
  }

  Host? hostById(String id) {
    for (final host in _hosts) {
      if (host.id == id) {
        return host;
      }
    }
    return null;
  }

  SshKey? keyById(String? id) {
    if (id == null) {
      return null;
    }
    for (final key in _keys) {
      if (key.id == id) {
        return key;
      }
    }
    return null;
  }

  int hostsUsingKey(String keyId) => _hosts.where((h) => h.keyId == keyId).length;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _corruptKeys.clear();
    final rawHosts = _readRaw(_hostsKey);
    final unsupported = rawHosts.items.where((h) => h['protocol'] == 'rdp').toList();
    _hosts = await _parse(
      _hostsKey,
      DecodedList(rawHosts.items.where((h) => h['protocol'] != 'rdp').toList(), corrupt: rawHosts.corrupt),
      Host.fromJson,
      (h) => h.id.isNotEmpty,
    );
    if (unsupported.isNotEmpty) {
      for (final host in unsupported) {
        final id = host['id'];
        if (id is String && id.isNotEmpty) {
          await _writeSecret(_passwordKey(id), null);
        }
      }
      await _saveHosts();
    }
    _keys = await _parse(_keysKey, _readRaw(_keysKey), SshKey.fromJson, (k) => k.id.isNotEmpty);
    final snippetsRaw = _prefs.getString(_snippetsKey);
    if (snippetsRaw == null) {
      _snippets = [
        Snippet(id: newId(), name: 'Processes', command: 'htop || top'),
        Snippet(id: newId(), name: 'Disks', command: 'df -h'),
        Snippet(id: newId(), name: 'Memory', command: 'free -h'),
        Snippet(id: newId(), name: 'Open ports', command: 'ss -tulpn'),
        Snippet(id: newId(), name: 'System log', command: 'journalctl -n 100 --no-pager'),
      ];
      await _saveSnippets();
    } else {
      _snippets = await _parse(_snippetsKey, _readRaw(_snippetsKey), Snippet.fromJson, (s) => s.id.isNotEmpty);
    }
    final known = decodeJsonMap(_prefs.getString(_knownHostsKey));
    if (known.corrupt) {
      await _backupCorrupt(_knownHostsKey);
    }
    _knownHosts = Map.fromEntries(known.items);
    final storedFont = _prefs.getDouble(_fontSizeKey);
    _fontSize = storedFont == null ? 14 : _limitFont(storedFont);
    _terminalTheme = _prefs.getString(_terminalThemeKey) ?? 'midnight';
    _terminalFont = _prefs.getString(_terminalFontKey) ?? 'jetbrains';
    _themeMode = _prefs.getString(_themeModeKey) ?? 'system';
    _lockEnabled = _prefs.getBool(_lockEnabledKey) ?? false;
    _biometricEnabled = _prefs.getBool(_biometricKey) ?? false;
    _secureScreen = _prefs.getBool(_secureScreenKey) ?? true;
    _vpnProfiles = await _parse(_vpnKey, _readRaw(_vpnKey), VpnProfile.fromJson, (p) => p.id.isNotEmpty);
    _wolDevices = await _parse(_wolKey, _readRaw(_wolKey), WolDevice.fromJson, (d) => d.id.isNotEmpty);
    notifyListeners();
  }

  DecodedList<Map<String, dynamic>> _readRaw(String key) => decodeJsonList(_prefs.getString(key));

  Future<List<T>> _parse<T>(
    String key,
    DecodedList<Map<String, dynamic>> raw,
    T Function(Map<String, dynamic>) parse,
    bool Function(T) valid,
  ) async {
    final result = parseItems(raw, parse, valid);
    if (result.corrupt) {
      await _backupCorrupt(key);
    }
    return result.items;
  }

  /// Keeps an untouched copy of an unreadable collection so the next save
  /// cannot silently destroy the user's data.
  Future<void> _backupCorrupt(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return;
    }
    await _prefs.setString('$key.corrupt.${DateTime.now().millisecondsSinceEpoch}', raw);
    _corruptKeys.add(key);
  }

  double _limitFont(double value) {
    if (value < 8) {
      return 8;
    }
    if (value > 28) {
      return 28;
    }
    return value;
  }

  Future<void> _saveHosts() => _prefs.setString(_hostsKey, jsonEncode(_hosts.map((h) => h.toJson()).toList()));

  Future<void> _saveKeys() => _prefs.setString(_keysKey, jsonEncode(_keys.map((k) => k.toJson()).toList()));

  Future<void> _saveSnippets() => _prefs.setString(_snippetsKey, jsonEncode(_snippets.map((s) => s.toJson()).toList()));

  Future<void> _saveKnownHosts() => _prefs.setString(_knownHostsKey, jsonEncode(_knownHosts));

  Future<void> _saveVpn() => _prefs.setString(_vpnKey, jsonEncode(_vpnProfiles.map((p) => p.toJson()).toList()));

  Future<void> _saveWol() => _prefs.setString(_wolKey, jsonEncode(_wolDevices.map((d) => d.toJson()).toList()));

  Future<void> saveWolDevice(WolDevice device) async {
    final index = _wolDevices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _wolDevices[index] = device;
    } else {
      _wolDevices.add(device);
    }
    await _saveWol();
    notifyListeners();
  }

  Future<void> deleteWolDevice(String id) async {
    _wolDevices.removeWhere((d) => d.id == id);
    await _saveWol();
    notifyListeners();
  }

  String _passwordKey(String hostId) => 'pw_$hostId';
  String _privateKeyKey(String keyId) => 'pk_$keyId';
  String _passphraseKey(String keyId) => 'pp_$keyId';
  String _vpnConfigKey(String id) => 'wg_$id';

  Future<String?> _readSecret(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecret(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _secure.delete(key: key);
    } else {
      await _secure.write(key: key, value: value);
    }
  }

  Future<String?> readPassword(String hostId) => _readSecret(_passwordKey(hostId));

  Future<bool> hasPassword(String hostId) async {
    final value = await readPassword(hostId);
    return value != null && value.isNotEmpty;
  }

  Future<void> savePassword(String hostId, String password) => _writeSecret(_passwordKey(hostId), password);

  Future<String?> readPrivateKey(String keyId) => _readSecret(_privateKeyKey(keyId));

  Future<String?> readPassphrase(String keyId) => _readSecret(_passphraseKey(keyId));

  Future<void> saveHost(Host host, {String? password}) async {
    final index = _hosts.indexWhere((h) => h.id == host.id);
    if (index >= 0) {
      _hosts[index] = host;
    } else {
      _hosts.add(host);
    }
    await _saveHosts();
    if (password != null) {
      await _writeSecret(_passwordKey(host.id), password);
    }
    notifyListeners();
  }

  Future<Host> duplicateHost(Host host) async {
    final title = host.label.trim().isEmpty ? host.address : host.label.trim();
    final copy = Host(
      id: newId(),
      protocol: host.protocol,
      label: 'hosts.copy_suffix'.tr(namedArgs: {'title': title}),
      group: host.group,
      address: host.address,
      port: host.port,
      username: host.username,
      auth: host.auth,
      keyId: host.keyId,
      startupCommand: host.startupCommand,
      color: host.color,
      legacy: host.legacy,
    );
    final password = await readPassword(host.id);
    await saveHost(copy, password: password);
    return copy;
  }

  Future<void> deleteHost(String hostId) async {
    _hosts.removeWhere((h) => h.id == hostId);
    await _saveHosts();
    await _writeSecret(_passwordKey(hostId), null);
    notifyListeners();
  }

  Future<void> touchHost(String hostId) async {
    final index = _hosts.indexWhere((h) => h.id == hostId);
    if (index < 0) {
      return;
    }
    _hosts[index] = _hosts[index].copyWith(lastUsed: DateTime.now());
    await _saveHosts();
    notifyListeners();
  }

  Future<void> saveKey(SshKey key, {String? privatePem, String? passphrase}) async {
    final index = _keys.indexWhere((k) => k.id == key.id);
    if (index >= 0) {
      _keys[index] = key;
    } else {
      _keys.add(key);
    }
    if (privatePem != null) {
      await _writeSecret(_privateKeyKey(key.id), privatePem);
    }
    if (passphrase != null) {
      await _writeSecret(_passphraseKey(key.id), passphrase);
    }
    await _saveKeys();
    notifyListeners();
  }

  Future<void> deleteKey(String keyId) async {
    _keys.removeWhere((k) => k.id == keyId);
    var hostsChanged = false;
    for (var i = 0; i < _hosts.length; i++) {
      if (_hosts[i].keyId == keyId) {
        _hosts[i] = _hosts[i].copyWith(clearKey: true, auth: AuthType.password);
        hostsChanged = true;
      }
    }
    await _saveKeys();
    if (hostsChanged) {
      await _saveHosts();
    }
    await _writeSecret(_privateKeyKey(keyId), null);
    await _writeSecret(_passphraseKey(keyId), null);
    notifyListeners();
  }

  Future<void> saveSnippet(Snippet snippet) async {
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    if (index >= 0) {
      _snippets[index] = snippet;
    } else {
      _snippets.add(snippet);
    }
    await _saveSnippets();
    notifyListeners();
  }

  Future<void> deleteSnippet(String snippetId) async {
    _snippets.removeWhere((s) => s.id == snippetId);
    await _saveSnippets();
    notifyListeners();
  }

  Future<void> trustHostKey(String endpoint, String fingerprint) async {
    _knownHosts[endpoint] = fingerprint;
    await _saveKnownHosts();
    notifyListeners();
  }

  Future<void> forgetHostKey(String endpoint) async {
    _knownHosts.remove(endpoint);
    await _saveKnownHosts();
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = _limitFont(value);
    notifyListeners();
    await _prefs.setDouble(_fontSizeKey, _fontSize);
  }

  Future<void> setTerminalTheme(String id) async {
    _terminalTheme = id;
    notifyListeners();
    await _prefs.setString(_terminalThemeKey, id);
  }

  Future<void> setTerminalFont(String id) async {
    _terminalFont = id;
    notifyListeners();
    await _prefs.setString(_terminalFontKey, id);
  }

  Future<void> setThemeMode(String value) async {
    _themeMode = value;
    await _prefs.setString(_themeModeKey, value);
  }

  Future<String?> readPin() => _readSecret(_pinKey);

  Future<void> savePinHash(String hash) => _writeSecret(_pinKey, hash);

  int get pinFailures => _prefs.getInt(_pinFailuresKey) ?? 0;

  DateTime? get pinLockedUntil {
    final ms = _prefs.getInt(_pinLockedUntilKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> recordPinFailure() async {
    final failures = pinFailures + 1;
    await _prefs.setInt(_pinFailuresKey, failures);
    final delay = PinThrottle.delayAfter(failures);
    if (delay > Duration.zero) {
      await _prefs.setInt(_pinLockedUntilKey, DateTime.now().add(delay).millisecondsSinceEpoch);
    }
  }

  Future<void> resetPinFailures() async {
    await _prefs.remove(_pinFailuresKey);
    await _prefs.remove(_pinLockedUntilKey);
  }

  Future<void> setSecureScreen(bool value) async {
    _secureScreen = value;
    await _prefs.setBool(_secureScreenKey, value);
    notifyListeners();
  }

  Future<void> setLock({required bool enabled, String? pin, bool? biometric}) async {
    _lockEnabled = enabled;
    await _prefs.setBool(_lockEnabledKey, enabled);
    if (pin != null) {
      await _writeSecret(_pinKey, await PinHasher.hash(pin));
      await resetPinFailures();
    }
    if (!enabled) {
      await _writeSecret(_pinKey, null);
      await resetPinFailures();
      _biometricEnabled = false;
      await _prefs.setBool(_biometricKey, false);
    }
    if (biometric != null) {
      _biometricEnabled = biometric;
      await _prefs.setBool(_biometricKey, biometric);
    }
    notifyListeners();
  }

  VpnProfile? vpnProfileById(String id) {
    for (final profile in _vpnProfiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }

  Future<String?> readVpnConfig(String id) => _readSecret(_vpnConfigKey(id));

  Future<void> saveVpnProfile(VpnProfile profile, {String? config}) async {
    final index = _vpnProfiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      _vpnProfiles[index] = profile;
    } else {
      _vpnProfiles.add(profile);
    }
    if (config != null) {
      await _writeSecret(_vpnConfigKey(profile.id), config);
    }
    await _saveVpn();
    notifyListeners();
  }

  Future<void> deleteVpnProfile(String id) async {
    _vpnProfiles.removeWhere((p) => p.id == id);
    await _writeSecret(_vpnConfigKey(id), null);
    await _saveVpn();
    notifyListeners();
  }

  Future<void> touchVpnProfile(String id) async {
    final index = _vpnProfiles.indexWhere((p) => p.id == id);
    if (index < 0) {
      return;
    }
    _vpnProfiles[index] = _vpnProfiles[index].copyWith(lastUsed: DateTime.now());
    await _saveVpn();
    notifyListeners();
  }
}
