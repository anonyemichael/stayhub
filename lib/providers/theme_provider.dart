import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // Start with system default (Light or Dark based on phone settings)
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // In a real scenario, we would need context to check system brightness,
      // but for logic checks, we return false or manage this in the UI.
      // This getter is mostly for toggle switches.
      return _themeMode == ThemeMode.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}