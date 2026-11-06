import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Display preferences: light/dark theme and the accent colour. Kept in
/// shared preferences; web/index.html also reads the accent
/// ("flutter.accent_color") to colour the loading screen and the iPhone
/// status bar before the app starts.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _themeKey = 'theme_mode';
  static const _accentKey = 'accent_color';

  ThemeMode themeMode = ThemeMode.system;
  Color accent = AppColors.defaultAccent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode =
        ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
        ThemeMode.system;
    final argb = prefs.getInt(_accentKey);
    if (argb != null) accent = Color(argb);
    AppColors.accent = accent;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setAccent(Color color) async {
    accent = color;
    AppColors.accent = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
  }
}
