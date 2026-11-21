import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/services/cash_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CashReminderService.nextAt', () {
    test('later today when the time is still ahead', () {
      final now = DateTime(2026, 11, 21, 18, 30);
      expect(
        CashReminderService.nextAt(now, 21, 0),
        DateTime(2026, 11, 21, 21, 0),
      );
    });

    test('tomorrow when the time has passed (or is right now)', () {
      expect(
        CashReminderService.nextAt(DateTime(2026, 11, 21, 21, 0), 21, 0),
        DateTime(2026, 11, 22, 21, 0),
      );
      expect(
        CashReminderService.nextAt(DateTime(2026, 11, 21, 22, 15), 21, 0),
        DateTime(2026, 11, 22, 21, 0),
      );
    });

    test('rolls over the end of a month and year', () {
      expect(
        CashReminderService.nextAt(DateTime(2026, 12, 31, 23, 0), 21, 0),
        DateTime(2027, 1, 1, 21, 0),
      );
    });
  });

  group('SettingsProvider cash reminder', () {
    test('on by default at 9:00 PM', () {
      final s = SettingsProvider();
      expect(s.cashReminderOn, isTrue);
      expect(s.cashReminderTime, const TimeOfDay(hour: 21, minute: 0));
    });

    test('minutes are saved and read back', () {
      const t = TimeOfDay(hour: 20, minute: 45);
      final m = SettingsProvider.timeToMinutes(t);
      expect(m, 1245);
      expect(SettingsProvider.minutesToTime(m), t);
    });

    test('missing or broken saved value falls back to 9:00 PM', () {
      const nine = TimeOfDay(hour: 21, minute: 0);
      expect(SettingsProvider.minutesToTime(null), nine);
      expect(SettingsProvider.minutesToTime(-5), nine);
      expect(SettingsProvider.minutesToTime(24 * 60), nine);
    });
  });
}
