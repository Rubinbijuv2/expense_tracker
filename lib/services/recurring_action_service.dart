import 'package:intl/intl.dart';

import '../data/category_repo.dart';
import '../data/recurring_installment_repo.dart';
import '../data/recurring_payment_repo.dart';
import '../data/transaction_repo.dart';
import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import 'budget_alert_service.dart';
import 'notification_service.dart';
import 'reminder_planner.dart';

/// "Mark as paid" pressed on a reminder notification. Runs in the
/// background isolate (the app does not open), like SmsActionService.
/// Chitti reminders open the app instead, because the amount can change.
class RecurringActionService {
  RecurringActionService({
    RecurringPaymentRepo? paymentRepo,
    RecurringInstallmentRepo? installmentRepo,
    TransactionRepo? transactionRepo,
    CategoryRepo? categoryRepo,
  }) : _payments = paymentRepo ?? RecurringPaymentRepo(),
       _insts = installmentRepo ?? RecurringInstallmentRepo(),
       _txns = transactionRepo ?? TransactionRepo(),
       _categories = categoryRepo ?? CategoryRepo();

  final RecurringPaymentRepo _payments;
  final RecurringInstallmentRepo _insts;
  final TransactionRepo _txns;
  final CategoryRepo _categories;

  static const String markPaidAction = 'rec_paid';
  static const String callAction = 'rec_call';

  /// Name the open app's RecurringProvider registers its mailbox under.
  static const String portName = 'recurring_action_port';

  /// Pays the installment at the usual amount and adds the expense.
  /// Returns false if it was already paid/skipped or no longer exists.
  Future<bool> markPaid(ReminderPayload payload) async {
    final p = await _payments.getById(payload.recurringId);
    if (p == null || p.id == null) return false;
    RecurringInstallment? inst;
    for (final i in await _insts.getFor(p.id!)) {
      if (i.id == payload.installmentId) inst = i;
    }
    if (inst == null || !inst.isPending) return false;

    final now = DateTime.now();
    int? txnId;
    if (await _categories.getById(p.categoryId) != null) {
      final txn = paymentTransaction(p, inst, p.amountPaise, now);
      txnId = await _txns.insert(txn);
      await BudgetAlertService().checkAfterSave(txn);
    }
    await _insts.update(inst.paid(p.amountPaise, txnId, now));
    // The overdue reminders of this installment are no longer needed.
    await NotificationService.instance.cancelIds(
      ReminderPlanner.idsForInstallment(inst.id!),
    );
    return true;
  }

  /// The expense created when an installment is paid (also used by
  /// RecurringProvider.markPaid, so both look the same).
  static TransactionModel paymentTransaction(
    RecurringPayment p,
    RecurringInstallment inst,
    int amountPaise,
    DateTime now,
  ) => TransactionModel(
    amountPaise: amountPaise,
    type: 'expense',
    categoryId: p.categoryId,
    paymentMode: p.paymentMode,
    dateTime: now,
    merchant: p.name,
    note: '${p.name} · due ${DateFormat('d MMM yyyy').format(inst.dueDate)}',
    recurringId: p.id,
  );
}
