import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';
import 'reminder_service.dart';

/// Daily "Spent any cash today?" reminder (PLAN.md section 6.1).
///
/// One notification repeats every day at the chosen time. Like the
/// repeat-payment reminders it is *inexact* (Android may show it a few
/// minutes late), so no exact-alarm permission is needed. The boot receiver
/// in AndroidManifest.xml brings it back after the phone restarts.
class CashReminderService {
  CashReminderService._();
  static final CashReminderService instance = CashReminderService._();

  /// Fixed id: below the SMS ids (1000+) and next to the scan summary (1).
  static const int notificationId = 2;

  /// Put on the notification so a tap opens Add with mode = Cash.
  static const String payload = 'cash';

  static const String title = 'Spent any cash today?';
  static const String body = 'Tap to add it before you forget';

  static const int defaultHour = 21; // 9:00 PM
  static const int defaultMinute = 0;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'cash_reminder',
      'Daily cash reminder',
      channelDescription: 'A daily nudge to add cash you spent',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  /// Turns the reminder on at [hour]:[minute] every day, or off.
  /// Safe to call often: it always cancels the old one first.
  Future<void> apply({
    required bool on,
    required int hour,
    required int minute,
  }) async {
    try {
      await NotificationService.instance.init();
      final plugin = NotificationService.instance.plugin;
      await plugin.cancel(id: notificationId);
      if (!on) return;
      await ReminderService.instance.initTimeZone();
      final at = nextAt(DateTime.now(), hour, minute);
      await plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeat every day at the same time of day.
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      debugPrint('Cash reminder scheduled daily, first at $at');
    } catch (e) {
      // Reminders are a bonus: never let them break the app.
      debugPrint('Could not schedule cash reminder: $e');
    }
  }

  /// Developer button: shows the reminder right now.
  Future<void> showNow() async {
    await NotificationService.instance.init();
    await NotificationService.instance.plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  /// The next [hour]:[minute] after [now]: today if still ahead, else
  /// tomorrow. Pure function, so it is unit-tested.
  static DateTime nextAt(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
}
