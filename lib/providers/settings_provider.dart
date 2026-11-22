import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cash_reminder_service.dart';

/// Theme, "onboarding finished" flag and the daily cash reminder, saved in
/// shared_preferences. (Older versions also saved a 'user_name'; it is left
/// there untouched and no longer used.)
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    this._themeMode = ThemeMode.system,
    this._onboardingDone = false,
    this._cashReminderOn = true,
    this._cashReminderTime = defaultCashReminderTime,
  });

  static const String _themeKey = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const String _onboardingKey = 'onboarding_done';
  static const String _cashOnKey = 'cash_reminder_on';
  static const String _cashTimeKey =
      'cash_reminder_minutes'; // minutes after midnight

  /// 9:00 PM. TimeOfDay is Flutter's "hour + minute, no date" class.
  static const TimeOfDay defaultCashReminderTime = TimeOfDay(
    hour: CashReminderService.defaultHour,
    minute: CashReminderService.defaultMinute,
  );

  ThemeMode _themeMode;
  bool _onboardingDone;
  bool _cashReminderOn;
  TimeOfDay _cashReminderTime;

  ThemeMode get themeMode => _themeMode;
  bool get onboardingDone => _onboardingDone;
  bool get cashReminderOn => _cashReminderOn;
  TimeOfDay get cashReminderTime => _cashReminderTime;

  /// Reads the saved values. Called in main() before the first frame,
  /// so the app knows straight away whether to show onboarding.
  static Future<SettingsProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SettingsProvider(
        themeMode: _parseTheme(prefs.getString(_themeKey)),
        onboardingDone: prefs.getBool(_onboardingKey) ?? false,
        cashReminderOn: prefs.getBool(_cashOnKey) ?? true,
        cashReminderTime: minutesToTime(prefs.getInt(_cashTimeKey)),
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

  /// 1260 → 9:00 PM. Missing or broken values → the 9:00 PM default.
  static TimeOfDay minutesToTime(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) {
      return defaultCashReminderTime;
    }
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  static int timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

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
    await applyCashReminder();
  }

  Future<void> setCashReminderOn(bool on) async {
    _cashReminderOn = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cashOnKey, on);
    await applyCashReminder();
  }

  Future<void> setCashReminderTime(TimeOfDay time) async {
    _cashReminderTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cashTimeKey, timeToMinutes(time));
    await applyCashReminder();
  }

  /// Schedules (or cancels) the daily cash reminder from the saved
  /// settings. Called on app start and after every change. Nothing is
  /// scheduled before onboarding is finished.
  Future<void> applyCashReminder() => CashReminderService.instance.apply(
    on: _cashReminderOn && _onboardingDone,
    hour: _cashReminderTime.hour,
    minute: _cashReminderTime.minute,
  );
}
