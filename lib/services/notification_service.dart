import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/detected_sms.dart';
import '../utils/formatters.dart';

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

  // Notification ids: one fixed id for the inbox-scan summary, and
  // 1000 + detected_sms.id for each SMS, so ids never clash.
  static const int _scanSummaryId = 1;
  static const int _smsIdOffset = 1000;

  static const AndroidNotificationDetails _smsChannel =
      AndroidNotificationDetails(
    'detected_sms',
    'Detected bank SMS',
    channelDescription: 'Suggestions created from your bank and UPI SMS',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Sets up the plugin once. [onTap] runs when the user taps a notification
  /// while the app is open or in the background.
  Future<void> init({VoidCallback? onTap}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse:
          onTap == null ? null : (_) => onTap(),
    );
    _ready = true;
  }

  /// True if the app was started (from closed) by tapping one of our notifications.
  Future<bool> launchedFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// "₹450 paid to Swiggy — tap to add"
  Future<void> showDetected(DetectedSms sms) async {
    await _safeShow(
      _smsIdOffset + (sms.id ?? 0),
      'New ${sms.type} detected',
      detectedText(sms),
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

  /// Removes the notification of an SMS once it is saved or ignored.
  Future<void> cancelForSms(int smsId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _smsIdOffset + smsId);
    } catch (e) {
      debugPrint('Could not cancel notification: $e');
    }
  }

  Future<void> _safeShow(int id, String title, String body) async {
    try {
      await init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _smsChannel),
      );
    } catch (e) {
      // Notifications are a bonus: never let them break SMS detection.
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

  /// Like formatPaise but drops ".00": 45000 → "₹450", 45050 → "₹450.50".
  static String shortAmount(int paise) {
    final text = formatPaise(paise);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }
}
