import 'package:sqflite/sqflite.dart';

import '../models/merchant_rule.dart';
import 'db_helper.dart';

/// All database work for the `merchant_rules` table.
class MerchantRuleRepo {
  final DbHelper _helper;
  MerchantRuleRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tMerchantRules;

  /// Throws if the keyword already exists — use [upsert] to replace instead.
  Future<int> insert(MerchantRule rule) async {
    final db = await _helper.database;
    return db.insert(_table, rule.toMap()..remove('id'));
  }

  Future<int> update(MerchantRule rule) async {
    final db = await _helper.database;
    return db.update(
      _table,
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<MerchantRule?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : MerchantRule.fromMap(rows.first);
  }

  Future<List<MerchantRule>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'keyword');
    return rows.map(MerchantRule.fromMap).toList();
  }

  /// Exact keyword lookup (keywords are stored lowercase).
  Future<MerchantRule?> findByKeyword(String keyword) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'keyword = ?',
      whereArgs: [keyword.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : MerchantRule.fromMap(rows.first);
  }

  /// Saves the rule; if the keyword already exists, its category is replaced.
  Future<void> upsert(String keyword, int categoryId) async {
    final db = await _helper.database;
    await db.insert(
      _table,
      MerchantRule(keyword: keyword, categoryId: categoryId).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
