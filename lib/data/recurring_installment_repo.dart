import '../models/recurring_installment.dart';
import 'db_helper.dart';

/// All database work for the `recurring_installments` table.
class RecurringInstallmentRepo {
  final DbHelper _helper;
  RecurringInstallmentRepo([DbHelper? helper])
    : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tRecurringInstallments;

  /// Every installment of every repeat payment, oldest due date first.
  Future<List<RecurringInstallment>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'due_date, id');
    return rows.map(RecurringInstallment.fromMap).toList();
  }

  /// Installments of one repeat payment, oldest due date first.
  Future<List<RecurringInstallment>> getFor(int recurringId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'recurring_id = ?',
      whereArgs: [recurringId],
      orderBy: 'due_date, id',
    );
    return rows.map(RecurringInstallment.fromMap).toList();
  }

  /// Adds pending installments for [dates] in one batch.
  Future<void> insertPending(int recurringId, List<DateTime> dates) async {
    if (dates.isEmpty) return;
    final db = await _helper.database;
    final batch = db.batch();
    for (final d in dates) {
      batch.insert(
        _table,
        RecurringInstallment(recurringId: recurringId, dueDate: d).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> update(RecurringInstallment i) async {
    final db = await _helper.database;
    return db.update(_table, i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  }

  /// Removes the pending ones (they hold no data), so they can be
  /// generated again after the schedule was edited.
  Future<int> deletePending(int recurringId) async {
    final db = await _helper.database;
    return db.delete(
      _table,
      where: "recurring_id = ? AND status = 'pending'",
      whereArgs: [recurringId],
    );
  }
}
