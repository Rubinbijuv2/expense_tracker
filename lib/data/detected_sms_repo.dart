import '../models/detected_sms.dart';
import 'db_helper.dart';

/// All database work for the `detected_sms` table.
class DetectedSmsRepo {
  final DbHelper _helper;
  DetectedSmsRepo([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  static const _table = DbHelper.tDetectedSms;

  Future<int> insert(DetectedSms sms) async {
    final db = await _helper.database;
    return db.insert(_table, sms.toMap()..remove('id'));
  }

  Future<int> update(DetectedSms sms) async {
    final db = await _helper.database;
    return db.update(_table, sms.toMap(), where: 'id = ?', whereArgs: [sms.id]);
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<DetectedSms?> getById(int id) async {
    final db = await _helper.database;
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DetectedSms.fromMap(rows.first);
  }

  /// Pending suggestions, newest first (Home strip and Detected SMS screen).
  Future<List<DetectedSms>> getPending({int? limit}) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(DetectedSms.fromMap).toList();
  }

  Future<int> countPending() async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_table WHERE status = ?',
      ['pending'],
    );
    return rows.first['n'] as int? ?? 0;
  }

  /// Sets status to 'pending', 'saved' or 'ignored'.
  Future<int> updateStatus(int id, String status) async {
    final db = await _helper.database;
    return db.update(_table, {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  /// "Ignore all" on the Detected SMS screen.
  Future<int> ignoreAllPending() async {
    final db = await _helper.database;
    return db.update(_table, {'status': 'ignored'},
        where: 'status = ?', whereArgs: ['pending']);
  }

  /// True if this exact SMS body was already stored (duplicate check).
  Future<bool> existsByBody(String body) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE body = ? LIMIT 1',
      [body],
    );
    return rows.isNotEmpty;
  }

  /// True if a *pending* SMS with the same amount and merchant arrived
  /// within [window] of [at] (PLAN.md rule 10). Merchant is case-insensitive.
  Future<bool> existsSimilarPending(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE status = ? AND amount_paise = ? '
      'AND LOWER(merchant) = LOWER(?) AND received_at >= ? AND received_at <= ? '
      'LIMIT 1',
      [
        'pending',
        amountPaise,
        merchant,
        at.subtract(window).toIso8601String(),
        at.add(window).toIso8601String(),
      ],
    );
    return rows.isNotEmpty;
  }
}
