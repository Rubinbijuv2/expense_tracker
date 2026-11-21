import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User name, theme and "onboarding finished" flag, saved in shared_preferences.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    this._name = '',
    this._themeMode = ThemeMode.system,
    this._onboardingDone = false,
  });

  static const String _nameKey = 'user_name';
  static const String _themeKey = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const String _onboardingKey = 'onboarding_done';

  String _name;
  ThemeMode _themeMode;
  bool _onboardingDone;

  String get name => _name;
  ThemeMode get themeMode => _themeMode;
  bool get onboardingDone => _onboardingDone;

  /// Reads the saved values. Called in main() before the first frame,
  /// so the app knows straight away whether to show onboarding.
  static Future<SettingsProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SettingsProvider(
        name: prefs.getString(_nameKey) ?? '',
        themeMode: _parseTheme(prefs.getString(_themeKey)),
        onboardingDone: prefs.getBool(_onboardingKey) ?? false,
      );
    } catch (e) {
      debugPrint('Could not read settings: $e');
      return SettingsProvider();
    }
  }

  static ThemeMode _parseTheme(String? s) => ThemeMode.values.firstWhere(
        (m) => m.name == s,
        orElse: () => ThemeMode.system,
      );

  Future<void> setName(String name) async {
    _name = name.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    _onboardingDone = true;
    notifyListeners();
  }
}
