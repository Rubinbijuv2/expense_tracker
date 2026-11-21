import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/category_repo.dart';
import '../data/detected_sms_repo.dart';
import '../data/merchant_rule_repo.dart';
import '../data/transaction_repo.dart';
import '../models/category_model.dart';
import '../models/detected_sms.dart';
import 'category_guesser.dart';
import 'notification_service.dart';
import 'sms_parser.dart';

/// Android calls this when a new SMS arrives while the app is in the
/// background or closed.
///
/// It must be a top-level function (not inside a class), and
/// `@pragma('vm:entry-point')` stops the compiler from removing it in
/// release builds, because nothing in our Dart code calls it directly.
@pragma('vm:entry-point')
Future<void> onBackgroundSms(SmsMessage message) async {
  await SmsService().handleIncoming(
      message.address, message.body, SmsService.dateOf(message));
}

/// What happened to one SMS: either the saved pending row, or why it was
/// ignored ("OTP message", "duplicate …").
class SmsResult {
  final DetectedSms? saved;
  final String? ignoredReason;

  const SmsResult.saved(DetectedSms this.saved) : ignoredReason = null;
  const SmsResult.ignored(String this.ignoredReason) : saved = null;

  bool get isSaved => saved != null;
}

/// Reads bank SMS and turns them into pending suggestions (PLAN.md section 4).
///
/// Steps for every SMS: sender filter + parse (sms_parser) → duplicate check
/// (rule 10) → category guess (category_guesser) → save to detected_sms as
/// 'pending'. SMS from non-bank senders are dropped at the first step and are
/// never stored or logged.
class SmsService {
  SmsService({
    DetectedSmsRepo? smsRepo,
    TransactionRepo? transactionRepo,
    MerchantRuleRepo? ruleRepo,
    CategoryRepo? categoryRepo,
  })  : _smsRepo = smsRepo ?? DetectedSmsRepo(),
        _txnRepo = transactionRepo ?? TransactionRepo(),
        _ruleRepo = ruleRepo ?? MerchantRuleRepo(),
        _categoryRepo = categoryRepo ?? CategoryRepo();

  final DetectedSmsRepo _smsRepo;
  final TransactionRepo _txnRepo;
  final MerchantRuleRepo _ruleRepo;
  final CategoryRepo _categoryRepo;

  static const int scanDays = 30;
  static const Duration duplicateWindow = Duration(minutes: 2);
  static const String _scanDoneKey = 'sms_inbox_scan_done';

  // A getter, so tests that never touch the phone don't create it.
  Telephony get _telephony => Telephony.instance;

  // ---- Permission ---------------------------------------------------------

  /// True if READ_SMS / RECEIVE_SMS are granted.
  static Future<bool> hasPermission() async {
    try {
      return await Permission.sms.isGranted;
    } catch (e) {
      debugPrint('Could not check SMS permission: $e');
      return false;
    }
  }

  /// Shows Android's permission popup. If the user earlier chose
  /// "Don't allow" twice, Android won't show the popup again, so we open the
  /// app's settings page instead. Returns true if permission is now granted.
  static Future<bool> requestPermission() async {
    if (await Permission.sms.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final granted = (await Permission.sms.request()).isGranted;
    if (granted) {
      // Android 13+ also needs permission to show notifications.
      // If the user says no, detection still works, just without popups.
      await Permission.notification.request();
    }
    return granted;
  }

  // ---- Reading SMS ---------------------------------------------------------

  /// Starts listening for new SMS. [onSaved] runs (in the open app) for every
  /// SMS that became a new pending suggestion (the notification is already shown).
  void startListening(void Function(DetectedSms sms) onSaved) {
    _telephony.listenIncomingSms(
      onNewMessage: (message) async {
        final result = await handleIncoming(
            message.address, message.body, dateOf(message));
        if (result.saved != null) onSaved(result.saved!);
      },
      onBackgroundMessage: onBackgroundSms,
    );
  }

  /// One newly arrived SMS: the full pipeline plus the notification.
  ///
  /// Every new SMS goes through here: the open-app listener, the background
  /// handler, and the developer Test SMS screen.
  Future<SmsResult> handleIncoming(
      String? sender, String? body, DateTime receivedAt) async {
    final result = await processMessage(sender, body, receivedAt);
    if (result.saved != null) {
      await NotificationService.instance.showDetected(result.saved!);
    }
    return result;
  }

  /// Reads the last [scanDays] days of the inbox, only the first time it is
  /// called (remembered in shared_preferences). Returns how many new pending
  /// suggestions were created.
  Future<int> scanInboxOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_scanDoneKey) ?? false) return 0;

    final since = DateTime.now().subtract(const Duration(days: scanDays));
    final messages = await _telephony.getInboxSms(
      columns: const [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.DATE)
          .greaterThan('${since.millisecondsSinceEpoch}'),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)], // oldest first
    );

    var created = 0;
    for (final m in messages) {
      // No notification per SMS here: one summary is shown afterwards.
      final result = await processMessage(m.address, m.body, dateOf(m));
      if (result.isSaved) created++;
    }
    await prefs.setBool(_scanDoneKey, true);
    debugPrint('Inbox scan: ${messages.length} SMS checked, $created new');
    return created;
  }

  /// The time an SMS arrived (Android gives milliseconds since 1970).
  static DateTime dateOf(SmsMessage m) => m.date == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(m.date!);

  // ---- The pipeline (no phone APIs below, so it is unit-tested) ----------

  /// Runs one SMS through every step (no notification). Returns the saved
  /// pending row, or the reason it was ignored.
  Future<SmsResult> processMessage(
      String? sender, String? body, DateTime receivedAt) async {
    if (sender == null || body == null || body.trim().isEmpty) {
      return const SmsResult.ignored('empty SMS');
    }

    // Rules 1–8. Non-bank senders, OTPs, offers etc. stop here.
    final parseResult = SmsParser.parseWithReason(sender, body);
    final parsed = parseResult.sms;
    if (parsed == null) return SmsResult.ignored(parseResult.ignoredReason!);

    // Rule 10: same SMS text already stored, or same amount + merchant
    // within ±2 minutes (e.g. the bank and the UPI app both sent an SMS).
    if (await _smsRepo.existsByBody(parsed.body)) {
      return const SmsResult.ignored('duplicate (same SMS already stored)');
    }
    if (await _txnRepo.existsSimilar(
        parsed.amountPaise, parsed.merchant, receivedAt,
        window: duplicateWindow)) {
      return const SmsResult.ignored(
          'duplicate (matches a transaction within 2 minutes)');
    }
    if (await _smsRepo.existsSimilarPending(
        parsed.amountPaise, parsed.merchant, receivedAt,
        window: duplicateWindow)) {
      return const SmsResult.ignored(
          'duplicate (matches a detected SMS within 2 minutes)');
    }

    final sms = DetectedSms(
      sender: parsed.sender,
      body: parsed.body,
      amountPaise: parsed.amountPaise,
      type: parsed.type,
      merchant: parsed.merchant,
      accountLast4: parsed.accountLast4,
      paymentMode: parsed.paymentMode,
      guessedCategoryId: await _guessCategoryId(parsed.merchant, parsed.type),
      receivedAt: receivedAt,
    );
    final id = await _smsRepo.insert(sms);
    return SmsResult.saved(sms.copyWith(id: id));
  }

  /// Rule 9, plus a safety net: the guessed category must match the type.
  /// Income falls back to the first income category (Salary);
  /// expense falls back to 'Others'.
  Future<int?> _guessCategoryId(String merchant, String type) async {
    final guess = CategoryGuesser.guess(merchant, await _ruleRepo.getAll());
    CategoryModel? category = guess.isFromRule
        ? await _categoryRepo.getById(guess.categoryId!)
        : await _categoryRepo.getByName(guess.categoryName!);

    if (category == null || category.type != type) {
      if (type == 'income') {
        final incomeCats = await _categoryRepo.getByType('income');
        category = incomeCats.isEmpty ? null : incomeCats.first;
      } else {
        category = await _categoryRepo.getByName(CategoryGuesser.fallback);
      }
    }
    return category?.id;
  }
}
