import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/detected_sms_repo.dart';
import '../data/ignored_sender_repo.dart';
import '../data/transaction_repo.dart';
import 'notification_parser.dart';
import 'notification_service.dart';
import 'sms_service.dart';

/// One notification from an allow-listed payment app, as sent by the
/// Kotlin PaymentNotificationListener (title + text + big text).
class AppNotification {
  final String packageName;
  final String title;
  final String text;
  final String? bigText;
  final DateTime postedAt;

  const AppNotification({
    required this.packageName,
    required this.title,
    required this.text,
    this.bigText,
    required this.postedAt,
  });

  factory AppNotification.fromMap(Map<Object?, Object?> map) {
    final ms = map['postedAt'] as int?;
    return AppNotification(
      packageName: map['package'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      bigText: map['bigText'] as String?,
      postedAt: ms == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}

/// Payment app notifications (PLAN.md section 7), off by default.
///
/// The Android side is our own small Kotlin service
/// (`PaymentNotificationListener.kt`). It drops every app that is not on
/// the allow-list BEFORE anything reaches Dart, and also drops everything
/// while the Settings switch is off. Allowed notifications come here by:
/// - an EventChannel (a stream from Kotlin) while the app is running, or
/// - [runInBackground], a hidden Dart engine Kotlin starts when the app is
///   closed.
/// Both go through [handleIncoming]: parse → duplicate check → the same
/// category guess / self transfer / Bank + Receipt pairing as SMS → pending
/// card → notification with Save / Ignore.
class PaymentNotificationService {
  PaymentNotificationService({
    SmsService? smsService,
    DetectedSmsRepo? smsRepo,
    TransactionRepo? transactionRepo,
    IgnoredSenderRepo? ignoredRepo,
  }) : _sms = smsService ?? SmsService(),
       _smsRepo = smsRepo ?? DetectedSmsRepo(),
       _txnRepo = transactionRepo ?? TransactionRepo(),
       _ignoredRepo = ignoredRepo ?? IgnoredSenderRepo();

  final SmsService _sms;
  final DetectedSmsRepo _smsRepo;
  final TransactionRepo _txnRepo;
  final IgnoredSenderRepo _ignoredRepo;

  /// Same notification seen again (apps update them): section 7.5.
  static const Duration duplicateWindow = Duration(minutes: 2);

  // A MethodChannel is a named "phone line" for calling Kotlin functions;
  // an EventChannel is a stream of events that Kotlin pushes to Dart.
  static const MethodChannel _channel = MethodChannel(
    'expense_tracker/notifications',
  );
  static const EventChannel _events = EventChannel(
    'expense_tracker/notification_events',
  );
  static const MethodChannel _bgChannel = MethodChannel(
    'expense_tracker/notification_background',
  );

  // ---- Android settings ------------------------------------------------------

  /// True if the user allowed us on Android's "Notification access" page.
  static Future<bool> hasAccess() => _call('hasAccess');

  /// True if the Settings switch is on (saved on the Kotlin side, so the
  /// service knows it even when the app is closed).
  static Future<bool> isEnabled() => _call('isEnabled');

  /// Opens Android's Notification access page for this app.
  static Future<bool> openAccessSettings() => _call('openAccessSettings');

  static Future<void> setEnabled(bool on) => _call('setEnabled', {'on': on});

  static Future<bool> _call(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (e) {
      debugPrint('Notification channel "$method" failed: $e');
      return false;
    }
  }

  /// Allowed payment notifications while the app is running.
  static Stream<AppNotification> liveEvents() => _events
      .receiveBroadcastStream()
      .map((e) => AppNotification.fromMap(e as Map<Object?, Object?>));

  /// Runs in the hidden engine Kotlin starts when the app is closed
  /// (main.dart's `paymentNotificationMain`).
  static Future<void> runInBackground() async {
    // Lets plugins (database, notifications) work outside the normal app.
    DartPluginRegistrant.ensureInitialized();
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Notifications not available: $e');
    }
    final service = PaymentNotificationService();
    _bgChannel.setMethodCallHandler((call) async {
      if (call.method != 'onNotification') return null;
      final n = AppNotification.fromMap(
        call.arguments as Map<Object?, Object?>,
      );
      final result = await service.handleIncoming(n);
      return result.isSaved;
    });
    // Tells Kotlin it can send the notifications it kept waiting.
    await _bgChannel.invokeMethod<void>('ready');
  }

  // ---- The pipeline ---------------------------------------------------------

  /// A new notification: the full pipeline plus our own notification.
  Future<SmsResult> handleIncoming(AppNotification n) async {
    final result = await process(n);
    if (result.saved != null) {
      await NotificationService.instance.showDetected(
        result.saved!,
        partner: await _sms.partnerOf(result.saved!),
      );
    }
    return result;
  }

  /// Runs one notification through every step (no phone APIs, so it is
  /// unit-tested). Other apps' notifications stop at the first step and
  /// nothing about them is stored.
  Future<SmsResult> process(AppNotification n) async {
    final parseResult = NotificationParser.parseWithReason(
      n.packageName,
      n.title,
      n.text,
      bigText: n.bigText,
      ignoredApps: await _ignoredRepo.getAll(),
    );
    final parsed = parseResult.sms;
    if (parsed == null) return SmsResult.ignored(parseResult.ignoredReason!);

    if (await _smsRepo.existsRecentFromApp(
      parsed.sender,
      parsed.amountPaise,
      parsed.body,
      n.postedAt,
      window: duplicateWindow,
    )) {
      return const SmsResult.ignored(
        'duplicate (same notification within 2 minutes)',
      );
    }
    if (await _txnRepo.existsSimilar(
      parsed.amountPaise,
      parsed.merchant,
      n.postedAt,
      window: duplicateWindow,
    )) {
      return const SmsResult.ignored(
        'duplicate (matches a transaction within 2 minutes)',
      );
    }

    // Category guess, self transfer and the bank SMS partner (30 minutes),
    // exactly as for an SMS.
    final pending = (await _sms.buildPending(
      parsed,
      n.postedAt,
    )).copyWith(source: 'notification', sourceApp: parsed.sender);
    final id = await _smsRepo.insert(pending);
    final saved = pending.copyWith(id: id);
    if (saved.duplicateOf != null) {
      await _smsRepo.setDuplicateOf(saved.duplicateOf!, id);
    }
    return SmsResult.saved(saved);
  }
}
