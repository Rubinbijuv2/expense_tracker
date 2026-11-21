import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db_helper.dart';

/// Thrown when a picked file is not an Expense Tracker backup.
class InvalidBackupException implements Exception {
  InvalidBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Backup (share the database file), restore (replace it with a picked
/// file) and "delete all data".
class BackupService {
  BackupService([DbHelper? helper]) : _helper = helper ?? DbHelper.instance;

  final DbHelper _helper;

  /// Every real SQLite file starts with these 16 bytes.
  static final Uint8List _sqliteHeader = Uint8List.fromList(
    'SQLite format 3\u0000'.codeUnits,
  );

  static const List<String> _requiredTables = [
    DbHelper.tCategories,
    DbHelper.tTransactions,
    DbHelper.tBudgets,
    DbHelper.tDetectedSms,
    DbHelper.tMerchantRules,
  ];

  /// Copies the database to a dated file and opens the share sheet.
  Future<void> backupAndShare() async {
    final source = await _helper.path;
    // Closing first writes any pending changes into the main .db file.
    await _helper.close();

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final out = File(p.join(dir.path, 'expense_tracker_backup_$stamp.db'));
    await File(source).copy(out.path);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(out.path, mimeType: 'application/octet-stream')],
        subject: 'Expense Tracker backup',
        text: 'Expense Tracker backup ($stamp). Keep this file safe.',
      ),
    );
  }

  /// Replaces the current database with [bytes] (the picked backup file).
  /// Throws [InvalidBackupException] and changes nothing if the file is wrong.
  Future<void> restoreFromBytes(Uint8List bytes) async {
    if (!_hasSqliteHeader(bytes)) {
      throw InvalidBackupException('This file is not a database backup.');
    }

    // Write the picked file to a temporary place and check it first.
    final tmpDir = await getTemporaryDirectory();
    final candidate = File(p.join(tmpDir.path, 'restore_candidate.db'));
    await candidate.writeAsBytes(bytes, flush: true);
    try {
      await _checkBackupFile(candidate.path);

      final target = await _helper.path;
      await _helper.close();
      // Remove leftover journal files so they are not mixed with the new DB.
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final f = File('$target$suffix');
        if (await f.exists()) await f.delete();
      }
      await candidate.copy(target);
    } finally {
      if (await candidate.exists()) await candidate.delete();
    }
    await _helper.database; // reopen
  }

  static bool _hasSqliteHeader(Uint8List bytes) {
    if (bytes.length < _sqliteHeader.length) return false;
    return listEquals(bytes.sublist(0, _sqliteHeader.length), _sqliteHeader);
  }

  /// Opens the file read-only and checks it has our 5 tables and a
  /// database version this app understands.
  Future<void> _checkBackupFile(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true, singleInstance: false);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = rows.map((r) => r['name'] as String).toSet();
      final missing = _requiredTables.where((t) => !names.contains(t));
      if (missing.isNotEmpty) {
        throw InvalidBackupException(
          'This database is not an Expense Tracker backup.',
        );
      }
      final version = await db.getVersion();
      if (version > DbHelper.dbVersion) {
        throw InvalidBackupException(
          'This backup is from a newer version of the app.',
        );
      }
    } on InvalidBackupException {
      rethrow;
    } catch (e) {
      debugPrint('Backup check failed: $e');
      throw InvalidBackupException('This file could not be read.');
    } finally {
      await db?.close();
    }
  }

  /// Empties every table and puts the default categories back.
  Future<void> deleteAllData() => _helper.resetAllData();
}
