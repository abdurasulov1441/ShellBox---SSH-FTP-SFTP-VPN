import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, success, warning, error }

class LogEntry {
  const LogEntry({required this.time, required this.level, required this.tag, required this.message});

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'l': level.index,
        'g': tag,
        'm': message,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final t = json['t'];
    final l = json['l'];
    return LogEntry(
      time: t is int ? DateTime.fromMillisecondsSinceEpoch(t) : DateTime.now(),
      level: l is int && l >= 0 && l < LogLevel.values.length ? LogLevel.values[l] : LogLevel.info,
      tag: json['g'] as String? ?? '',
      message: json['m'] as String? ?? '',
    );
  }
}

class ActivityLog extends ChangeNotifier {
  ActivityLog._();

  static final ActivityLog instance = ActivityLog._();

  static const _key = 'activity_log';
  static const _max = 400;

  SharedPreferences? _prefs;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => _entries.reversed.toList(growable: false);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(decoded.whereType<Map>().map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {}
  }

  void log(LogLevel level, String tag, String message) {
    _entries.add(LogEntry(time: DateTime.now(), level: level, tag: tag, message: message));
    if (_entries.length > _max) {
      _entries.removeRange(0, _entries.length - _max);
    }
    notifyListeners();
    _persist();
  }

  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void success(String tag, String message) => log(LogLevel.success, tag, message);
  void warning(String tag, String message) => log(LogLevel.warning, tag, message);
  void error(String tag, String message) => log(LogLevel.error, tag, message);

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    await _prefs?.remove(_key);
  }

  String exportText() {
    final buffer = StringBuffer();
    for (final e in _entries) {
      buffer.writeln('${e.time.toIso8601String()}  [${e.level.name.toUpperCase()}]  ${e.tag}: ${e.message}');
    }
    return buffer.toString();
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    prefs.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}
