import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import 'notification_service.dart';
import 'recurring_action_service.dart';
import 'reminder_planner.dart';

/// Schedules repeat-payment reminders with the notification plugin.
///
/// Scheduling is *inexact* (`inexactAllowWhileIdle`): Android may show a
/// reminder some minutes late to save battery, but we need no exact-alarm
/// permission. Everything is cancelled and scheduled again on every change.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  bool _tzReady = false;
  Future<void> _queue = Future.value();

  static const String _channelId = 'repeat_reminders';
  static const String _channelName = 'Repeat payment reminders';

  /// The `timezone` package needs to know the phone's time zone
  /// (for example Asia/Kolkata) to turn "9:00 AM" into an exact moment.
  Future<void> _initTimeZone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Time zone not found, using India time: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    _tzReady = true;
  }

  /// Cancels old reminders and schedules the current plan. Calls are run
  /// one after another, so two quick changes can't mix their reminders.
  Future<void> reschedule(
    List<RecurringPayment> items,
    Map<int, List<RecurringInstallment>> installments,
  ) {
    final copyItems = List.of(items);
    final copyInsts = Map.of(installments);
    return _queue = _queue.then((_) => _reschedule(copyItems, copyInsts));
  }

  Future<void> _reschedule(
    List<RecurringPayment> items,
    Map<int, List<RecurringInstallment>> installments,
  ) async {
    try {
      await NotificationService.instance.init();
      await _initTimeZone();
      final plugin = NotificationService.instance.plugin;
      for (final old in await plugin.pendingNotificationRequests()) {
        if (ReminderPlanner.isReminderId(old.id)) {
          await plugin.cancel(id: old.id);
        }
      }
      final plan = ReminderPlanner.plan(
        items: items,
        installments: installments,
        now: DateTime.now(),
      );
      for (final r in plan) {
        await _schedule(r, tz.TZDateTime.from(r.at, tz.local));
      }
      debugPrint('Scheduled ${plan.length} repeat-payment reminders');
    } catch (e) {
      // Reminders are a bonus: never let them break the app.
      debugPrint('Could not schedule reminders: $e');
    }
  }

  Future<void> _schedule(PlannedReminder r, tz.TZDateTime when) =>
      NotificationService.instance.plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: when,
        notificationDetails: details(r),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: r.payload,
      );

  /// Channel + the Mark as paid / Call organiser buttons.
  static NotificationDetails details(PlannedReminder r) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Bills, EMI, chitti and fees that are due',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          RecurringActionService.markPaidAction,
          'Mark as paid',
          // Chitti: open the app to ask the amount (it changes monthly).
          showsUserInterface: r.isChitti,
        ),
        if (r.isChitti && r.hasPhone)
          const AndroidNotificationAction(
            RecurringActionService.callAction,
            'Call organiser',
            showsUserInterface: true,
          ),
      ],
    ),
  );

  // ---- Developer test buttons ----------------------------------------------

  /// Shows a reminder for [p] / [inst] right now (no scheduling).
  Future<void> showTestNow(
    RecurringPayment p,
    RecurringInstallment inst,
  ) async {
    await NotificationService.instance.init();
    final r = _testReminder(p, inst, DateTime.now());
    await NotificationService.instance.plugin.show(
      id: r.id,
      title: r.title,
      body: r.body,
      notificationDetails: details(r),
      payload: r.payload,
    );
  }

  /// Schedules a test reminder 1 minute from now, through the same inexact
  /// scheduling as real reminders (Android may delay it a few minutes).
  Future<void> scheduleTestInOneMinute(
    RecurringPayment p,
    RecurringInstallment inst,
  ) async {
    await NotificationService.instance.init();
    await _initTimeZone();
    final at = DateTime.now().add(const Duration(minutes: 1));
    final r = _testReminder(p, inst, at);
    await _schedule(r, tz.TZDateTime.from(at, tz.local));
  }

  PlannedReminder _testReminder(
    RecurringPayment p,
    RecurringInstallment inst,
    DateTime at,
  ) => PlannedReminder(
    id: ReminderPlanner.testId,
    at: at,
    title: '${p.name} due (test reminder)',
    body: 'This is a test. Try the buttons below.',
    recurringId: p.id!,
    installmentId: inst.id!,
    isChitti: p.isChitti,
    hasPhone: (p.organiserPhone ?? '').trim().isNotEmpty,
  );
}
