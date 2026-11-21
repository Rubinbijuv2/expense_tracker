import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/category_repo.dart';
import '../data/detected_sms_repo.dart';
import '../data/transaction_repo.dart';
import '../models/detected_sms.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import 'budget_alert_service.dart';
import 'recurring_action_service.dart';
import 'reminder_planner.dart';

/// Android calls this when the user taps **Save** or **Ignore** on a
/// detected-SMS notification (PLAN.md rule 14). It runs in a separate
/// background isolate, even when the app is closed, so the app never opens.
///
/// `@pragma('vm:entry-point')` keeps it in release builds, because nothing
/// in our Dart code calls it directly.
@pragma('vm:entry-point')
Future<void> onNotificationAction(NotificationResponse response) async {
  // Lets plugins written in Dart work in this background isolate too.
  DartPluginRegistrant.ensureInitialized();
  // A repeat-payment reminder's "Mark as paid" (payload "rec:…").
  final reminder = ReminderPayload.parse(response.payload);
  if (reminder != null) {
    if (response.actionId != RecurringActionService.markPaidAction) return;
    try {
      if (await RecurringActionService().markPaid(reminder)) {
        IsolateNameServer.lookupPortByName(RecurringActionService.portName)
            ?.send(reminder.recurringId);
      }
    } catch (e) {
      debugPrint('Reminder action failed: $e');
    }
    return;
  }
  final smsId = int.tryParse(response.payload ?? '');
  if (smsId == null) return;
  try {
    final done = await SmsActionService().handle(response.actionId, smsId);
    // If the app is open, tell it to reload its lists. A SendPort is a
    // mailbox address one isolate can use to post a message to another.
    if (done) {
      IsolateNameServer.lookupPortByName(SmsActionService.portName)
          ?.send(smsId);
    }
  } catch (e) {
    debugPrint('Notification action failed: $e');
  }
}

/// Save / Ignore a pending detected SMS without any screen.
class SmsActionService {
  SmsActionService({
    DetectedSmsRepo? smsRepo,
    TransactionRepo? transactionRepo,
    CategoryRepo? categoryRepo,
    this.budgetAlerts,
  }) : _smsRepo = smsRepo ?? DetectedSmsRepo(),
       _txnRepo = transactionRepo ?? TransactionRepo(),
       _categoryRepo = categoryRepo ?? CategoryRepo();

  final DetectedSmsRepo _smsRepo;
  final TransactionRepo _txnRepo;
  final CategoryRepo _categoryRepo;
  /// Null in the app: a real BudgetAlertService is made only when needed.
  final BudgetAlertService? budgetAlerts;

  static const String saveAction = 'save_sms';
  static const String ignoreAction = 'ignore_sms';

  /// Name the open app registers its mailbox (ReceivePort) under.
  static const String portName = 'sms_action_port';

  /// Returns true if something changed. Does nothing if the SMS was already
  /// saved or ignored in the app, or if Save has no valid category.
  Future<bool> handle(String? actionId, int smsId) async {
    final sms = await _smsRepo.getById(smsId);
    if (sms == null || !sms.isPending) return false;

    if (actionId == ignoreAction) {
      await _smsRepo.updateStatus(smsId, 'ignored');
      return true;
    }
    if (actionId != saveAction) return false;

    final categoryId = sms.guessedCategoryId;
    if (categoryId == null || await _categoryRepo.getById(categoryId) == null) {
      return false; // the notification has no Save button in this case
    }
    final txn = toTransaction(sms, categoryId);
    await _txnRepo.insert(txn);
    await _smsRepo.updateStatus(smsId, 'saved');
    await (budgetAlerts ?? BudgetAlertService()).checkAfterSave(txn);
    return true;
  }

  /// The transaction a detected SMS becomes (also used by the app's Save).
  static TransactionModel toTransaction(DetectedSms sms, int categoryId) =>
      TransactionModel(
        amountPaise: sms.amountPaise,
        type: sms.type,
        categoryId: categoryId,
        paymentMode: sms.paymentMode ?? AppConstants.defaultPaymentMode,
        dateTime: sms.receivedAt,
        merchant: sms.merchant,
        source: 'sms',
        smsId: sms.id,
        isSelfTransfer: sms.isSelfTransfer,
      );
}
