import '../models/budget.dart';
import 'db_helper.dart';

/// All database work for the `budgets` table.
/// Months are 'YYYY-MM' strings — use `monthKey()` from utils/formatters.dart.
class BudgetRepo {
  final DbHelper _helper;
  BudgetRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tBudgets;

  /// Throws a DatabaseException if a budget for the same month + category
  /// already exists. Use [setLimit] when you just want "create or change".
  Future<int> insert(Budget budget) async {
    final db = await _helper.database;
    return db.insert(_table, budget.toMap()..remove('id'));
  }

  Future<int> update(Budget budget) async {
    final db = await _helper.database;
    return db.update(_table, budget.toMap(),
        where: 'id = ?', whereArgs: [budget.id]);
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Budget?> getById(int id) async {
    final db = await _helper.database;
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  /// All budgets for a month; the overall budget (no category) comes first.
  Future<List<Budget>> getForMonth(String month) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'category_id IS NOT NULL, category_id',
    );
    return rows.map(Budget.fromMap).toList();
  }

  /// The overall monthly budget, or null if none is set.
  Future<Budget?> getOverall(String month) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'month = ? AND category_id IS NULL',
      whereArgs: [month],
      limit: 1,
    );
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  Future<Budget?> getForCategory(String month, int categoryId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'month = ? AND category_id = ?',
      whereArgs: [month, categoryId],
      limit: 1,
    );
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  /// Creates the budget, or changes the limit if one already exists.
  /// Changing the limit resets the alerts so they can fire again.
  /// [categoryId] null = overall budget.
  Future<void> setLimit(String month, int? categoryId, int limitPaise) async {
    final existing = categoryId == null
        ? await getOverall(month)
        : await getForCategory(month, categoryId);
    if (existing == null) {
      await insert(Budget(
          month: month, categoryId: categoryId, limitPaise: limitPaise));
    } else {
      await update(existing.copyWith(
        limitPaise: limitPaise,
        alert80Sent: false,
        alert100Sent: false,
      ));
    }
  }
}
