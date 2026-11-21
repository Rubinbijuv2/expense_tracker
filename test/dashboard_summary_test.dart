import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _food = CategoryModel(
    id: 1, name: 'Food', icon: 'restaurant', color: 0xFFEF6C00, type: 'expense');
const _travel = CategoryModel(
    id: 2, name: 'Travel', icon: 'directions_car', color: 0xFF1E88E5, type: 'expense');
const _salary = CategoryModel(
    id: 9, name: 'Salary', icon: 'account_balance_wallet', color: 0xFF43A047, type: 'income');

final _cats = {1: _food, 2: _travel, 9: _salary};
CategoryModel? _lookup(int id) => _cats[id];

TransactionModel _txn(int id, int paise, String type, int cat, DateTime when) =>
    TransactionModel(
      id: id,
      amountPaise: paise,
      type: type,
      categoryId: cat,
      paymentMode: 'UPI',
      dateTime: when,
    );

void main() {
  final nov = DateTime(2026, 11);

  test('empty list gives zeros', () {
    final s = DashboardSummary.compute([], nov, _lookup);
    expect(s.spentPaise, 0);
    expect(s.incomePaise, 0);
    expect(s.balancePaise, 0);
    expect(s.byCategory, isEmpty);
    expect(s.recent, isEmpty);
  });

  test('totals only count the chosen month (boundaries included)', () {
    final txns = [
      _txn(1, 10000, 'expense', 1, DateTime(2026, 12, 1, 0, 0)), // next month
      _txn(2, 25000, 'expense', 1, DateTime(2026, 11, 30, 23, 59)), // last minute
      _txn(3, 5000000, 'income', 9, DateTime(2026, 11, 15)),
      _txn(4, 12000, 'expense', 2, DateTime(2026, 11, 1, 0, 0)), // first minute
      _txn(5, 99900, 'expense', 1, DateTime(2026, 10, 31, 23, 59)), // last month
    ];
    final s = DashboardSummary.compute(txns, nov, _lookup);
    expect(s.spentPaise, 37000);
    expect(s.incomePaise, 5000000);
    expect(s.balancePaise, 5000000 - 37000);
    expect(s.recent.map((t) => t.id), [2, 3, 4]);
  });

  test('balance can be negative', () {
    final s = DashboardSummary.compute([
      _txn(1, 50000, 'expense', 1, DateTime(2026, 11, 2)),
      _txn(2, 20000, 'income', 9, DateTime(2026, 11, 1)),
    ], nov, _lookup);
    expect(s.balancePaise, -30000);
  });

  test('pie slices: expenses only, grouped by category, biggest first', () {
    final s = DashboardSummary.compute([
      _txn(1, 10000, 'expense', 1, DateTime(2026, 11, 5)),
      _txn(2, 30000, 'expense', 2, DateTime(2026, 11, 4)),
      _txn(3, 15000, 'expense', 1, DateTime(2026, 11, 3)),
      _txn(4, 900000, 'income', 9, DateTime(2026, 11, 2)),
    ], nov, _lookup);
    expect(s.byCategory.map((c) => c.name), ['Travel', 'Food']);
    expect(s.byCategory.map((c) => c.totalPaise), [30000, 25000]);
    expect(s.byCategory.first.color, 0xFF1E88E5);
  });

  test('unknown category still shows as a slice', () {
    final s = DashboardSummary.compute(
        [_txn(1, 100, 'expense', 77, DateTime(2026, 11, 5))], nov, _lookup);
    expect(s.byCategory.single.name, 'Unknown');
  });

  test('recent keeps only the newest 5 of the month', () {
    final txns = [
      for (var day = 20; day >= 10; day--)
        _txn(day, 100, 'expense', 1, DateTime(2026, 11, day)),
    ];
    final s = DashboardSummary.compute(txns, nov, _lookup);
    expect(s.recent.map((t) => t.id), [20, 19, 18, 17, 16]);
    expect(s.spentPaise, 1100); // totals still use all 11
  });
}
