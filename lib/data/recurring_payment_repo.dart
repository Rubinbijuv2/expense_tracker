import '../models/recurring_payment.dart';
import 'db_helper.dart';

/// All database work for the `recurring_payments` table.
class RecurringPaymentRepo {
  final DbHelper _helper;
  RecurringPaymentRepo([DbHelper? helper])
    : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tRecurringPayments;

  Future<int> insert(RecurringPayment p) async {
    final db = await _helper.database;
    return db.insert(_table, p.toMap()..remove('id'));
  }

  Future<int> update(RecurringPayment p) async {
    final db = await _helper.database;
    return db.update(_table, p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  /// Its installments are deleted too (ON DELETE CASCADE); transactions are
  /// kept and only lose the link (ON DELETE SET NULL).
  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<RecurringPayment?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RecurringPayment.fromMap(rows.first);
  }

  /// All repeat payments, active first, then by name.
  Future<List<RecurringPayment>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      orderBy: 'active DESC, name COLLATE NOCASE',
    );
    return rows.map(RecurringPayment.fromMap).toList();
  }

  /// Records (or clears, with nulls) the chitti lump sum.
  Future<void> setChittiReceived(int id, int? paise, DateTime? date) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {
        'chitti_received_paise': paise,
        'chitti_received_date': date?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
