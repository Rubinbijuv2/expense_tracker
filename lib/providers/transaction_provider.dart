import 'package:flutter/foundation.dart';

import '../data/category_repo.dart';
import '../data/transaction_repo.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/budget_alert_service.dart';

/// All transactions of one calendar day, with that day's totals.
class DayGroup {
  DayGroup(this.day);

  final DateTime day; // midnight of that day
  final List<TransactionModel> items = [];
  int expensePaise = 0;
  int incomePaise = 0;
}

/// Holds the transaction list and categories for the screens.
///
/// A ChangeNotifier is an object that calls `notifyListeners()` when its data
/// changes; every screen watching it (via `context.watch`) then rebuilds.
class TransactionProvider extends ChangeNotifier {
  TransactionProvider({
    TransactionRepo? transactionRepo,
    CategoryRepo? categoryRepo,
    BudgetAlertService? budgetAlerts,
  })  : _txnRepo = transactionRepo ?? TransactionRepo(),
        _categoryRepo = categoryRepo ?? CategoryRepo(),
        _budgetAlerts = budgetAlerts ?? BudgetAlertService();

  final TransactionRepo _txnRepo;
  final CategoryRepo _categoryRepo;
  final BudgetAlertService _budgetAlerts;

  List<TransactionModel> _transactions = [];
  Map<int, CategoryModel> _categories = {};
  bool _loading = true;
  String? _error;

  /// All transactions, newest first.
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _loading;
  String? get error => _error;

  CategoryModel? categoryById(int id) => _categories[id];

  /// Categories for the Add/Edit grid: only 'expense' or only 'income' ones.
  List<CategoryModel> categoriesFor(String type) =>
      _categories.values.where((c) => c.type == type).toList();

  /// Loads (or reloads) categories and transactions from the database.
  Future<void> load() async {
    try {
      final cats = await _categoryRepo.getAll();
      _categories = {for (final c in cats) c.id!: c};
      _transactions = await _txnRepo.getAll();
      _error = null;
    } catch (e) {
      _error = 'Could not load transactions: $e';
      debugPrint(_error);
    }
    _loading = false;
    notifyListeners();
  }

  /// Every save (manual or from a detected SMS) goes through [add] or
  /// [update], so this is the one place where budgets are checked.
  /// Returns the new row's id (repeat payments link their installment to it).
  Future<int> add(TransactionModel txn) async {
    final id = await _txnRepo.insert(txn);
    await load();
    await _budgetAlerts.checkAfterSave(txn);
    return id;
  }

  Future<void> update(TransactionModel txn) async {
    await _txnRepo.update(txn);
    await load();
    await _budgetAlerts.checkAfterSave(txn);
  }

  /// Removes [txn] from the list right away (the swiped row must disappear
  /// at once), then deletes it from the database.
  Future<void> delete(TransactionModel txn) async {
    _transactions.removeWhere((t) => t.id == txn.id);
    notifyListeners();
    try {
      await _txnRepo.delete(txn.id!);
    } catch (e) {
      await load(); // Put the list back in sync if the delete failed.
      rethrow;
    }
  }

  /// Undo for [delete]: inserts the same row again with its old id.
  Future<void> restore(TransactionModel txn) async {
    await _txnRepo.restore(txn);
    await load();
    await _budgetAlerts.checkAfterSave(txn);
  }

  // ---- Categories (Settings → Manage categories) ---------------------------

  /// All categories, defaults first.
  List<CategoryModel> get allCategories => _categories.values.toList();

  /// True if another category of the same type already has this name.
  bool categoryNameTaken(String name, String type, {int? exceptId}) =>
      _categories.values.any((c) =>
          c.type == type &&
          c.id != exceptId &&
          c.name.toLowerCase() == name.trim().toLowerCase());

  Future<void> saveCategory(CategoryModel category) async {
    if (category.id == null) {
      await _categoryRepo.insert(category);
    } else {
      await _categoryRepo.update(category);
    }
    await load();
  }

  /// Deletes a custom category. Returns false (and deletes nothing) if a
  /// transaction still uses it, or if it is one of the default categories.
  Future<bool> deleteCategory(CategoryModel category) async {
    if (category.isDefault || category.id == null) return false;
    if (await _categoryRepo.isUsed(category.id!)) return false;
    await _categoryRepo.delete(category.id!);
    await load();
    return true;
  }

  /// Transactions grouped by day, newest day first, with daily totals.
  List<DayGroup> get groupedByDay => groupByDay(_transactions);

  /// Pure helper (no database), so it can be unit-tested.
  /// Expects [txns] sorted newest first.
  static List<DayGroup> groupByDay(List<TransactionModel> txns) {
    final groups = <DayGroup>[];
    for (final t in txns) {
      final day = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      if (groups.isEmpty || groups.last.day != day) groups.add(DayGroup(day));
      final g = groups.last;
      g.items.add(t);
      if (!t.counts) continue; // self transfer: shown, not added up
      if (t.isExpense) {
        g.expensePaise += t.amountPaise;
      } else {
        g.incomePaise += t.amountPaise;
      }
    }
    return groups;
  }
}
