import 'package:flutter/foundation.dart';

import '../data/budget_repo.dart';
import '../models/budget.dart';
import '../models/category_model.dart';
import '../models/category_total.dart';
import '../models/transaction_model.dart';
import '../services/budget_carry_over.dart';
import '../utils/formatters.dart';
import 'transaction_provider.dart';

/// Totals for one month, worked out from a list of transactions.
/// Pure Dart (no database, no Flutter), so it is easy to unit-test.
class DashboardSummary {
  const DashboardSummary({
    required this.spentPaise,
    required this.incomePaise,
    required this.byCategory,
    required this.recent,
  });

  final int spentPaise;
  final int incomePaise;

  /// Spending per category, biggest first (the pie chart slices).
  final List<CategoryTotal> byCategory;

  /// The newest transactions of the month (at most [recentCount]).
  final List<TransactionModel> recent;

  int get balancePaise => incomePaise - spentPaise;

  static const int recentCount = 5;

  static const empty = DashboardSummary(
    spentPaise: 0,
    incomePaise: 0,
    byCategory: [],
    recent: [],
  );

  /// Builds the summary for the month containing [month].
  /// [txns] must be sorted newest first (as TransactionProvider keeps them).
  /// [categoryById] looks up a category's name, icon and colour.
  static DashboardSummary compute(
    List<TransactionModel> txns,
    DateTime month,
    CategoryModel? Function(int id) categoryById,
  ) {
    var spent = 0;
    var income = 0;
    final perCategory = <int, int>{}; // category id → paise spent
    final recent = <TransactionModel>[];

    for (final t in txns) {
      if (t.dateTime.year != month.year || t.dateTime.month != month.month) {
        continue;
      }
      if (recent.length < recentCount) recent.add(t);
      if (!t.counts) continue; // self transfer: listed, never counted
      if (t.isExpense) {
        spent += t.amountPaise;
        perCategory[t.categoryId] =
            (perCategory[t.categoryId] ?? 0) + t.amountPaise;
      } else {
        income += t.amountPaise;
      }
    }

    final byCategory = perCategory.entries.map((e) {
      final cat = categoryById(e.key);
      return CategoryTotal(
        categoryId: e.key,
        name: cat?.name ?? 'Unknown',
        icon: cat?.icon ?? '',
        color: cat?.color ?? 0xFF9E9E9E,
        totalPaise: e.value,
      );
    }).toList()..sort((a, b) => b.totalPaise.compareTo(a.totalPaise));

    return DashboardSummary(
      spentPaise: spent,
      incomePaise: income,
      byCategory: byCategory,
      recent: recent,
    );
  }
}

/// Data for the Home screen: the chosen month, its totals and its budget.
///
/// It "listens" to [TransactionProvider]: every time a transaction is added,
/// edited, deleted or restored, [_recompute] runs and Home rebuilds.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._txns, {BudgetRepo? budgetRepo})
    : _budgetRepo = budgetRepo ?? BudgetRepo() {
    _txns.addListener(_recompute);
    _recompute();
    loadBudget();
  }

  final TransactionProvider _txns;
  final BudgetRepo _budgetRepo;

  DateTime _month = _monthOf(DateTime.now());
  DashboardSummary _summary = DashboardSummary.empty;
  Budget? _budget;

  /// First day of the month being shown.
  DateTime get month => _month;
  DashboardSummary get summary => _summary;

  /// The overall budget for [month], or null if none is set.
  Budget? get budget => _budget;

  /// Budget minus spent; negative when over budget. Null if no budget.
  int? get budgetLeftPaise =>
      _budget == null ? null : _budget!.limitPaise - _summary.spentPaise;

  /// The month switcher cannot go past the current month.
  bool get canGoNext => _month.isBefore(_monthOf(DateTime.now()));

  void previousMonth() => _setMonth(DateTime(_month.year, _month.month - 1));

  void nextMonth() {
    if (canGoNext) _setMonth(DateTime(_month.year, _month.month + 1));
  }

  void _setMonth(DateTime m) {
    _month = m;
    _budget = null; // don't show last month's budget while loading
    _recompute();
    loadBudget();
  }

  void _recompute() {
    _summary = DashboardSummary.compute(
      _txns.transactions,
      _month,
      _txns.categoryById,
    );
    notifyListeners();
  }

  /// Reads the overall budget for the shown month from the database.
  Future<void> loadBudget() async {
    final requested = _month;
    try {
      if (requested == _monthOf(DateTime.now())) {
        await BudgetCarryOver.ensureCurrentMonth(repo: _budgetRepo);
      }
      final b = await _budgetRepo.getOverall(monthKey(requested));
      // Ignore the answer if the user switched month while we waited.
      if (requested != _month) return;
      _budget = b;
    } catch (e) {
      debugPrint('Could not load budget: $e');
      _budget = null;
    }
    notifyListeners();
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  @override
  void dispose() {
    _txns.removeListener(_recompute);
    super.dispose();
  }
}
