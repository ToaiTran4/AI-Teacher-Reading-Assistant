import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider quản lý theme (Light/Dark mode)
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Mặc định theo hệ thống

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  /// Đọc theme đã lưu từ SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';

    switch (savedTheme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Lưu theme vào SharedPreferences
  Future<void> _saveThemeToPrefs(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', theme);
  }

  /// Đổi sang Light Mode
  void setLightMode() {
    _themeMode = ThemeMode.light;
    _saveThemeToPrefs('light');
    notifyListeners();
  }

  /// Đổi sang Dark Mode
  void setDarkMode() {
    _themeMode = ThemeMode.dark;
    _saveThemeToPrefs('dark');
    notifyListeners();
  }

  /// Đổi sang System Mode (Theo hệ thống)
  void setSystemMode() {
    _themeMode = ThemeMode.system;
    _saveThemeToPrefs('system');
    notifyListeners();
  }

  /// Toggle giữa Light và Dark mode
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setDarkMode();
    } else {
      setLightMode();
    }
  }
}
