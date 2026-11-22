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
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
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
    return db.update(
      _table,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// "Ignore all" on the Detected SMS screen.
  Future<int> ignoreAllPending() async {
    final db = await _helper.database;
    return db.update(
      _table,
      {'status': 'ignored'},
      where: 'status = ?',
      whereArgs: ['pending'],
    );
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

  /// "Always ignore this sender": marks that sender's pending rows as
  /// ignored. Returns their ids (so their notifications can be removed).
  Future<List<int>> ignorePendingFromSender(String sender) async {
    final db = await _helper.database;
    final from = sender.trim().toUpperCase();
    final rows = await db.query(
      _table,
      columns: ['id'],
      where: 'status = ? AND UPPER(sender) = ?',
      whereArgs: ['pending', from],
    );
    await db.update(
      _table,
      {'status': 'ignored'},
      where: 'status = ? AND UPPER(sender) = ?',
      whereArgs: ['pending', from],
    );
    return [for (final r in rows) r['id'] as int];
  }

  /// Rule 12: a pending, not-yet-paired SMS of kind [otherKind] ('bank' or
  /// 'receipt') with the same amount within [window] of [at]. The closest
  /// in time wins.
  Future<DetectedSms?> findPairPartner(
    int amountPaise,
    String otherKind,
    DateTime at, {
    Duration window = const Duration(minutes: 30),
  }) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where:
          'status = ? AND kind = ? AND amount_paise = ? AND duplicate_of IS NULL '
          'AND is_self_transfer = 0 AND received_at >= ? AND received_at <= ?',
      whereArgs: [
        'pending',
        otherKind,
        amountPaise,
        at.subtract(window).toIso8601String(),
        at.add(window).toIso8601String(),
      ],
    );
    final found = rows.map(DetectedSms.fromMap).toList()
      ..sort(
        (a, b) => a.receivedAt
            .difference(at)
            .abs()
            .compareTo(b.receivedAt.difference(at).abs()),
      );
    return found.isEmpty ? null : found.first;
  }

  /// Links (or with null, unlinks) one side of a Bank + Receipt pair.
  Future<int> setDuplicateOf(int id, int? otherId) async {
    final db = await _helper.database;
    return db.update(
      _table,
      {'duplicate_of': otherId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// True if a *pending* SMS with the same amount and merchant arrived
  /// within [window] of [at] (PLAN.md rule 10). Merchant is case-insensitive.
  /// Payment app notifications are not counted here: a bank SMS and a
  /// notification for the same payment become a merge card (section 7.5).
  Future<bool> existsSimilarPending(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE status = ? AND source = ? '
      'AND amount_paise = ? '
      'AND LOWER(merchant) = LOWER(?) AND received_at >= ? AND received_at <= ? '
      'LIMIT 1',
      [
        'pending',
        'sms',
        amountPaise,
        merchant,
        at.subtract(window).toIso8601String(),
        at.add(window).toIso8601String(),
      ],
    );
    return rows.isNotEmpty;
  }

  /// Section 7.5: payment apps often update a notification, so the same
  /// one arrives again. True if [app] already gave this amount and text
  /// within [window] of [at] (any status, so a saved one also counts).
  Future<bool> existsRecentFromApp(
    String app,
    int amountPaise,
    String body,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE source = ? AND sender = ? '
      'AND amount_paise = ? AND body = ? '
      'AND received_at >= ? AND received_at <= ? LIMIT 1',
      [
        'notification',
        app,
        amountPaise,
        body,
        at.subtract(window).toIso8601String(),
        at.add(window).toIso8601String(),
      ],
    );
    return rows.isNotEmpty;
  }
}
