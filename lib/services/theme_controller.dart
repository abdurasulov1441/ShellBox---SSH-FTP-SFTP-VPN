import 'package:flutter/material.dart';

import '../theme.dart';
import 'store.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void loadMode(ThemeMode mode) {
    _mode = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    await AppStore.instance.setThemeMode(modeToString(mode));
  }

  bool resolveIsDark(Brightness platform) {
    switch (_mode) {
      case ThemeMode.system:
        return platform == Brightness.dark;
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
    }
  }

  AppPalette resolvePalette(Brightness platform) => resolveIsDark(platform) ? darkPalette : lightPalette;

  static ThemeMode modeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static String modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}
