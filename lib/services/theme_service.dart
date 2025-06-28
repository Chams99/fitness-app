import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);

  ValueNotifier<ThemeMode> get themeMode => _themeMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('darkMode');

    if (isDarkMode == null) {
      _themeMode.value = ThemeMode.system;
    } else if (isDarkMode) {
      _themeMode.value = ThemeMode.dark;
    } else {
      _themeMode.value = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();

    switch (mode) {
      case ThemeMode.light:
        await prefs.setBool('darkMode', false);
        break;
      case ThemeMode.dark:
        await prefs.setBool('darkMode', true);
        break;
      case ThemeMode.system:
        await prefs.remove('darkMode');
        break;
    }

    _themeMode.value = mode;
  }

  Future<void> toggleTheme() async {
    final currentMode = _themeMode.value;
    if (currentMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  bool get isDarkMode {
    return _themeMode.value == ThemeMode.dark;
  }

  bool get isLightMode {
    return _themeMode.value == ThemeMode.light;
  }

  bool get isSystemMode {
    return _themeMode.value == ThemeMode.system;
  }
}
