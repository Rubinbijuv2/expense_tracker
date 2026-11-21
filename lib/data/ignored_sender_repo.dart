import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

/// All database work for the `ignored_senders` table
/// ("Always ignore this sender" on a detected SMS card).
class IgnoredSenderRepo {
  final DbHelper _helper;
  IgnoredSenderRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tIgnoredSenders;

  /// Senders are stored in capitals, e.g. "AX-HDFCBK-S". Adding one twice is fine.
  Future<void> add(String sender) async {
    final db = await _helper.database;
    await db.insert(_table, {
      'sender': sender.trim().toUpperCase(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> remove(String sender) async {
    final db = await _helper.database;
    return db.delete(
      _table,
      where: 'sender = ?',
      whereArgs: [sender.trim().toUpperCase()],
    );
  }

  /// Every ignored sender, for the SMS parser's sender filter.
  Future<Set<String>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, columns: ['sender']);
    return {for (final r in rows) r['sender'] as String};
  }
}
