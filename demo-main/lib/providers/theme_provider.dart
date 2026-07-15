import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ThemeProvider manages the application's theme mode (light/dark).
/// It detects the system's current brightness and allows the user
/// to manually toggle dark mode on or off, or follow system settings.
class ThemeProvider extends ChangeNotifier {
  /// The current theme mode: system, light, or dark
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Whether the dark mode is currently active (resolved from system or manual)
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // Detect system brightness
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Whether the user has chosen to follow the system setting
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Toggle dark mode on/off (sets manual mode, not system)
  void toggleDarkMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Set to follow system theme
  void useSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }

  /// Set a specific theme mode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
