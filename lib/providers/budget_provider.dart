import 'package:flutter/foundation.dart';

import '../data/budget_repo.dart';
import '../models/budget.dart';
import '../models/category_model.dart';
import '../services/budget_carry_over.dart';
import '../utils/formatters.dart';
import 'transaction_provider.dart';

/// Data for the Budgets screen: the chosen month, its budgets and how much
/// was spent (overall and per category).
///
/// Spending comes from [TransactionProvider]'s list, so the bars update by
/// themselves when a transaction is added, edited or deleted.
class BudgetProvider extends ChangeNotifier {
  BudgetProvider(this._txns, {BudgetRepo? budgetRepo})
    : _repo = budgetRepo ?? BudgetRepo() {
    _txns.addListener(_recompute);
    _recompute();
    load();
  }

  final TransactionProvider _txns;
  final BudgetRepo _repo;

  DateTime _month = _monthOf(DateTime.now());
  Budget? _overall;
  Map<int, Budget> _byCategory = {}; // category id → budget
  int _spentTotal = 0;
  Map<int, int> _spentByCategory = {}; // category id → paise spent
  String? _copySourceMonth; // 'YYYY-MM' that "Copy" would copy from
  bool _loading = true;

  DateTime get month => _month;
  Budget? get overall => _overall;
  Budget? budgetFor(int categoryId) => _byCategory[categoryId];
  int get spentTotal => _spentTotal;
  int spentFor(int categoryId) => _spentByCategory[categoryId] ?? 0;
  bool get isLoading => _loading;

  /// True when this month has no budgets but an earlier month does.
  bool get canCopyFromEarlier =>
      _overall == null && _byCategory.isEmpty && _copySourceMonth != null;

  /// Only expense categories can have a limit.
  List<CategoryModel> get expenseCategories => _txns.categoriesFor('expense');

  void previousMonth() => _setMonth(DateTime(_month.year, _month.month - 1));

  /// You can plan up to next month, but not further.
  bool get canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month + 1));
  }

  void nextMonth() {
    if (canGoNext) _setMonth(DateTime(_month.year, _month.month + 1));
  }

  /// Opens the screen on the same month the caller is showing (e.g. Home).
  void showMonth(DateTime m) {
    if (_monthOf(m) != _month) _setMonth(_monthOf(m));
  }

  void _setMonth(DateTime m) {
    _month = m;
    _overall = null;
    _byCategory = {};
    _copySourceMonth = null;
    _loading = true;
    _recompute();
    load();
  }

  /// Adds up this month's expenses from the in-memory transaction list.
  void _recompute() {
    var total = 0;
    final perCat = <int, int>{};
    for (final t in _txns.transactions) {
      if (!t.isExpense || !t.counts) continue; // skip income, self transfers
      if (t.dateTime.year != _month.year || t.dateTime.month != _month.month) {
        continue;
      }
      total += t.amountPaise;
      perCat[t.categoryId] = (perCat[t.categoryId] ?? 0) + t.amountPaise;
    }
    _spentTotal = total;
    _spentByCategory = perCat;
    notifyListeners();
  }

  /// Reads the budgets of the chosen month from the database.
  Future<void> load() async {
    final requested = _month;
    try {
      if (requested == _monthOf(DateTime.now())) {
        await BudgetCarryOver.ensureCurrentMonth(repo: _repo);
      }
      final key = monthKey(requested);
      final list = await _repo.getForMonth(key);
      final source = await _repo.latestMonthBefore(key);
      // Ignore the answer if the user switched month while we waited.
      if (requested != _month) return;
      _overall = list.where((b) => b.isOverall).firstOrNull;
      _byCategory = {
        for (final b in list)
          if (b.categoryId != null) b.categoryId!: b,
      };
      _copySourceMonth = source;
    } catch (e) {
      debugPrint('Could not load budgets: $e');
    }
    _loading = false;
    notifyListeners();
  }

  /// Creates or changes a limit. [categoryId] null = overall budget.
  Future<void> setLimit(int? categoryId, int limitPaise) async {
    await _repo.setLimit(monthKey(_month), categoryId, limitPaise);
    await load();
  }

  Future<void> removeLimit(int? categoryId) async {
    final b = categoryId == null ? _overall : _byCategory[categoryId];
    if (b?.id == null) return;
    await _repo.delete(b!.id!);
    await load();
  }

  /// "Copy last month's budgets". Returns how many budgets were copied.
  Future<int> copyFromEarlier() async {
    final n = await _repo.copyFromLatestBefore(monthKey(_month));
    await load();
    return n;
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  @override
  void dispose() {
    _txns.removeListener(_recompute);
    super.dispose();
  }
}
