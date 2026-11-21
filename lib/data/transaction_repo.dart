import '../models/category_total.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import 'db_helper.dart';

/// All database work for the `transactions` table, including the
/// totals the dashboard needs.
class TransactionRepo {
  final DbHelper _helper;
  TransactionRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tTransactions;

  Future<int> insert(TransactionModel txn) async {
    final db = await _helper.database;
    return db.insert(_table, txn.toMap()..remove('id'));
  }

  /// Inserts many rows in one batch (used by "Load demo data").
  Future<void> insertAll(List<TransactionModel> txns) async {
    final db = await _helper.database;
    final batch = db.batch();
    for (final t in txns) {
      batch.insert(_table, t.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<int> update(TransactionModel txn) async {
    final db = await _helper.database;
    return db.update(_table, txn.toMap(), where: 'id = ?', whereArgs: [txn.id]);
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<TransactionModel?> getById(int id) async {
    final db = await _helper.database;
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TransactionModel.fromMap(rows.first);
  }

  /// Every transaction, newest first (for the History screen).
  Future<List<TransactionModel>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'date_time DESC, id DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Transactions matching [filter] (search + filters), newest first.
  /// The WHERE clause only has `?` placeholders; values go in `whereArgs`.
  Future<List<TransactionModel>> search(TransactionFilter filter) async {
    final db = await _helper.database;
    final (where, args) = filter.toWhere();
    final rows = await db.query(
      _table,
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_time DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Puts a deleted transaction back with its old id (used by "Undo").
  Future<int> restore(TransactionModel txn) async {
    final db = await _helper.database;
    return db.insert(_table, txn.toMap());
  }

  /// The newest [limit] transactions (for "Recent" on Home).
  Future<List<TransactionModel>> recent(int limit) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      orderBy: 'date_time DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Every transaction in the month that contains [month], newest first.
  Future<List<TransactionModel>> getForMonth(DateTime month) async {
    final db = await _helper.database;
    final (start, end) = monthRange(month);
    final rows = await db.query(
      _table,
      where: 'date_time >= ? AND date_time < ?',
      whereArgs: [start, end],
      orderBy: 'date_time DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Sum of amounts of one [type] ('expense' or 'income') in a month, in paise.
  /// Returns 0 when there are no transactions.
  Future<int> totalByType(DateTime month, String type) async {
    final db = await _helper.database;
    final (start, end) = monthRange(month);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_paise), 0) AS total FROM $_table '
      'WHERE type = ? AND date_time >= ? AND date_time < ?',
      [type, start, end],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// Totals per category for one [type] in a month, biggest first.
  /// Used for the pie chart.
  Future<List<CategoryTotal>> totalsByCategory(
      DateTime month, String type) async {
    final db = await _helper.database;
    final (start, end) = monthRange(month);
    final rows = await db.rawQuery(
      'SELECT c.id AS category_id, c.name, c.icon, c.color, '
      'SUM(t.amount_paise) AS total_paise '
      'FROM $_table t JOIN ${DbHelper.tCategories} c ON c.id = t.category_id '
      'WHERE t.type = ? AND t.date_time >= ? AND t.date_time < ? '
      'GROUP BY c.id ORDER BY total_paise DESC',
      [type, start, end],
    );
    return rows.map(CategoryTotal.fromMap).toList();
  }

  /// Total spent in one category in a month (for per-category budgets).
  Future<int> totalForCategory(DateTime month, int categoryId) async {
    final db = await _helper.database;
    final (start, end) = monthRange(month);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_paise), 0) AS total FROM $_table '
      "WHERE type = 'expense' AND category_id = ? "
      'AND date_time >= ? AND date_time < ?',
      [categoryId, start, end],
    );
    return rows.first['total'] as int? ?? 0;
  }

  /// True if a transaction with the same amount and merchant exists within
  /// [window] of [at] (duplicate check for detected SMS, PLAN.md rule 10).
  Future<bool> existsSimilar(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE amount_paise = ? '
      'AND LOWER(merchant) = LOWER(?) AND date_time >= ? AND date_time <= ? '
      'LIMIT 1',
      [
        amountPaise,
        merchant,
        at.subtract(window).toIso8601String(),
        at.add(window).toIso8601String(),
      ],
    );
    return rows.isNotEmpty;
  }

  /// Start (inclusive) and end (exclusive) of the month containing [month],
  /// as ISO-8601 strings that compare correctly with stored `date_time`.
  /// Returns a "record" — two values in one, read with `final (a, b) = ...`.
  static (String, String) monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1); // Dec + 1 → next Jan
    return (start.toIso8601String(), end.toIso8601String());
  }
}
