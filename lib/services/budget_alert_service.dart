import 'package:flutter/foundation.dart';

import '../data/budget_repo.dart';
import '../data/category_repo.dart';
import '../data/transaction_repo.dart';
import '../models/budget.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import 'notification_service.dart';

/// Which alert (if any) a budget needs right now.
enum BudgetAlert { none, reached80, reached100 }

/// After a transaction is saved, checks the overall budget and that
/// category's budget for the transaction's month, and sends a notification
/// once at 80% and once at 100% (tracked by alert_80_sent / alert_100_sent).
class BudgetAlertService {
  BudgetAlertService({
    BudgetRepo? budgetRepo,
    TransactionRepo? transactionRepo,
    CategoryRepo? categoryRepo,
    Future<void> Function(int id, String title, String body)? notify,
  })  : _budgetRepo = budgetRepo ?? BudgetRepo(),
        _txnRepo = transactionRepo ?? TransactionRepo(),
        _categoryRepo = categoryRepo ?? CategoryRepo(),
        _notify = notify ?? NotificationService.instance.showBudgetAlert;

  final BudgetRepo _budgetRepo;
  final TransactionRepo _txnRepo;
  final CategoryRepo _categoryRepo;
  final Future<void> Function(int id, String title, String body) _notify;

  /// Call after every save. Income never counts towards a budget.
  /// Never throws: a failed alert must not break saving.
  Future<void> checkAfterSave(TransactionModel txn) async {
    if (!txn.isExpense) return;
    try {
      final month = DateTime(txn.dateTime.year, txn.dateTime.month);
      final key = monthKey(month);

      final overall = await _budgetRepo.getOverall(key);
      if (overall != null) {
        final spent = await _txnRepo.totalByType(month, 'expense');
        await _check(overall, spent, 'monthly budget');
      }

      final catBudget =
          await _budgetRepo.getForCategory(key, txn.categoryId);
      if (catBudget != null) {
        final spent = await _txnRepo.totalForCategory(month, txn.categoryId);
        final cat = await _categoryRepo.getById(txn.categoryId);
        await _check(catBudget, spent, '${cat?.name ?? 'category'} budget');
      }
    } catch (e) {
      debugPrint('Budget check failed: $e');
    }
  }

  Future<void> _check(Budget b, int spentPaise, String label) async {
    final alert = decide(
        spentPaise, b.limitPaise, b.alert80Sent, b.alert100Sent);
    if (alert == BudgetAlert.none) return;

    // Mark as sent first, so even if the notification fails it never repeats.
    // Reaching 100% also marks 80%, so a late "80%" alert never follows it.
    await _budgetRepo.update(b.copyWith(
      alert80Sent: true,
      alert100Sent: alert == BudgetAlert.reached100 ? true : b.alert100Sent,
    ));
    final (title, body) = alertText(alert, label, spentPaise, b.limitPaise);
    await _notify(b.id ?? 0, title, body);
  }

  /// Pure decision (no database), so it is unit-tested.
  static BudgetAlert decide(
      int spentPaise, int limitPaise, bool sent80, bool sent100) {
    if (limitPaise <= 0) return BudgetAlert.none;
    if (spentPaise >= limitPaise) {
      return sent100 ? BudgetAlert.none : BudgetAlert.reached100;
    }
    // spent * 100 >= limit * 80 means "at least 80%" without decimals.
    if (spentPaise * 100 >= limitPaise * 80 && !sent80) {
      return BudgetAlert.reached80;
    }
    return BudgetAlert.none;
  }

  /// Notification title and text, e.g.
  /// "80% of Food budget used" / "₹4,000 of ₹5,000 spent this month".
  static (String, String) alertText(
      BudgetAlert alert, String label, int spentPaise, int limitPaise) {
    final spent = NotificationService.shortAmount(spentPaise);
    final limit = NotificationService.shortAmount(limitPaise);
    final name = label[0].toUpperCase() + label.substring(1);
    if (alert == BudgetAlert.reached100) {
      return (
        '$name exceeded',
        'You have spent $spent of your $limit $label.',
      );
    }
    return (
      '80% of $label used',
      '$spent of $limit spent this month.',
    );
  }
}
