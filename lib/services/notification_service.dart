import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/detected_sms.dart';
import '../utils/formatters.dart';
import 'sms_action_service.dart';

/// Shows local notifications (no internet: they are created on the phone).
///
/// Used from two places:
/// - the main app (with [init]'s `onTap`, so tapping opens Detected SMS);
/// - the background SMS handler, which runs in a separate "isolate"
///   (a separate copy of Dart with its own memory) and only shows notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Notification ids: one fixed id for the inbox-scan summary,
  // 1000 + detected_sms.id for each SMS, 1000000 + budgets.id for
  // budget alerts and 2000000+ for repeat-payment reminders
  // (ReminderPlanner.idFor), so ids never clash.
  static const int _scanSummaryId = 1;
  static const int _smsIdOffset = 1000;
  static const int _budgetIdOffset = 1000000;

  static const AndroidNotificationDetails _budgetChannel =
      AndroidNotificationDetails(
        'budget_alerts',
        'Budget alerts',
        channelDescription: 'Warnings when you reach 80% or 100% of a budget',
        importance: Importance.high,
        priority: Priority.high,
      );

  static const AndroidNotificationDetails _smsChannel =
      AndroidNotificationDetails(
        'detected_sms',
        'Detected bank SMS',
        channelDescription: 'Suggestions created from your bank and UPI SMS',
        importance: Importance.high,
        priority: Priority.high,
      );

  /// The plugin itself (ReminderService schedules reminders with it).
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Sets up the plugin once. [onResponse] runs when the user taps a
  /// notification (or a button that opens the app) while the app is open or
  /// in the background; main.dart decides which screen to show.
  Future<void> init({void Function(NotificationResponse)? onResponse}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      // The Save / Ignore / Mark as paid buttons run here, without opening
      // the app. Always passed (also from the background SMS handler) so
      // Android keeps knowing which Dart function to call.
      onDidReceiveBackgroundNotificationResponse: onNotificationAction,
    );
    _ready = true;
  }

  /// The tap that started the app from closed, or null if it was not
  /// started by one of our notifications.
  Future<NotificationResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse;
  }

  /// "₹450 paid to Swiggy — tap to add", with **Save** and **Ignore**
  /// buttons (rule 14). Self transfers get no notification (they are not
  /// spending). A Bank + Receipt pair asks the user to open the app instead,
  /// because only the Detected SMS screen can merge them.
  Future<void> showDetected(DetectedSms sms) async {
    if (sms.isSelfTransfer || sms.id == null) return;
    final paired = sms.duplicateOf != null;
    await _safeShow(
      _smsIdOffset + sms.id!,
      paired
          ? (sms.isNotification
                ? 'Found in ${sms.sourceApp} and bank SMS'
                : 'Looks like the same payment')
          : 'New ${sms.type} detected',
      paired ? pairedText(sms) : detectedText(sms),
      payload: '${sms.id}',
      actions: paired
          ? null
          : [
              if (sms.guessedCategoryId != null)
                const AndroidNotificationAction(
                  SmsActionService.saveAction,
                  'Save',
                ),
              const AndroidNotificationAction(
                SmsActionService.ignoreAction,
                'Ignore',
              ),
            ],
    );
  }

  /// One summary after the first 30-day inbox scan, instead of one per SMS.
  Future<void> showScanSummary(int count) async {
    if (count <= 0) return;
    await _safeShow(
      _scanSummaryId,
      'Bank SMS found',
      'Found $count bank SMS from the last 30 days — tap to review',
    );
  }

  /// "80% of Food budget used" — sent by BudgetAlertService.
  Future<void> showBudgetAlert(int budgetId, String title, String body) =>
      _safeShow(
        _budgetIdOffset + budgetId,
        title,
        body,
        channel: _budgetChannel,
      );

  /// Android 13+ needs the user's OK to show notifications. Asked when the
  /// user sets a budget (SMS setup also asks). Does nothing if already granted.
  Future<void> requestPermission() async {
    try {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Removes the notification of an SMS once it is saved or ignored.
  Future<void> cancelForSms(int smsId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _smsIdOffset + smsId);
    } catch (e) {
      debugPrint('Could not cancel notification: $e');
    }
  }

  /// Removes shown or scheduled notifications (used after "Mark as paid").
  Future<void> cancelIds(Iterable<int> ids) async {
    try {
      await init();
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('Could not cancel notifications: $e');
    }
  }

  Future<void> _safeShow(
    int id,
    String title,
    String body, {
    AndroidNotificationDetails channel = _smsChannel,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    try {
      await init();
      final android = actions == null
          ? channel
          : AndroidNotificationDetails(
              channel.channelId,
              channel.channelName,
              channelDescription: channel.channelDescription,
              importance: channel.importance,
              priority: channel.priority,
              actions: actions,
            );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: android),
        payload: payload,
      );
    } catch (e) {
      // Notifications are a bonus: never let them break SMS detection or saving.
      debugPrint('Could not show notification: $e');
    }
  }

  /// Notification text. Pure function, so it is unit-tested.
  static String detectedText(DetectedSms sms) {
    final amount = shortAmount(sms.amountPaise);
    final merchant = sms.merchant ?? 'Unknown';
    return sms.type == 'income'
        ? '$amount received from $merchant — tap to add'
        : '$amount paid to $merchant — tap to add';
  }

  /// "₹450 to Swiggy — matches another SMS. Tap to merge"
  static String pairedText(DetectedSms sms) =>
      '${shortAmount(sms.amountPaise)} ${sms.type == 'income' ? 'from' : 'to'} '
      '${sms.merchant ?? 'Unknown'} — matches another SMS. Tap to merge';

  /// Like formatPaise but drops ".00": 45000 → "₹450", 45050 → "₹450.50".
  static String shortAmount(int paise) {
    final text = formatPaise(paise);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }
}
