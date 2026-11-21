import 'package:sqflite/sqflite.dart';

import '../models/own_account.dart';
import 'db_helper.dart';

/// All database work for the `own_accounts` table (Settings → My accounts).
class OwnAccountRepo {
  final DbHelper _helper;
  OwnAccountRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tOwnAccounts;

  /// Returns the new id, or 0 if these digits were already saved.
  Future<int> insert(OwnAccount account) async {
    final db = await _helper.database;
    return db.insert(
      _table,
      account.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<OwnAccount>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'id');
    return rows.map(OwnAccount.fromMap).toList();
  }

  /// Just the digits, for self-transfer detection.
  Future<Set<String>> getAllLast4() async =>
      (await getAll()).map((a) => a.last4).toSet();
}
