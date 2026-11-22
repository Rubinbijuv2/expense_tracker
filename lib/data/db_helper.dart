import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'db_schema.dart';

/// Opens the single SQLite database, creates the tables on first run and
/// upgrades older databases (the SQL itself is in db_schema.dart).
///
/// Repos call `DbHelper.instance.database` to get the open database.
/// It is a "singleton": there is only ever one DbHelper object in the app.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  static const String dbName = 'expense_tracker.db';

  /// Raising this number makes sqflite call [_onUpgrade] once on every phone
  /// that still has the older database.
  static const int dbVersion = 3;

  // Table names, used by the repos so the spelling lives in one place.
  static const String tCategories = Tables.categories;
  static const String tTransactions = Tables.transactions;
  static const String tBudgets = Tables.budgets;
  static const String tDetectedSms = Tables.detectedSms;
  static const String tMerchantRules = Tables.merchantRules;
  static const String tIgnoredSenders = Tables.ignoredSenders;
  static const String tOwnAccounts = Tables.ownAccounts;
  static const String tRecurringPayments = Tables.recurringPayments;
  static const String tRecurringInstallments = Tables.recurringInstallments;

  Database? _db;

  /// Returns the open database, opening it the first time it is needed.
  Future<Database> get database async {
    return _db ??= await _open();
  }

  /// Full path of the database file on the phone (used by backup/restore).
  Future<String> get path async => join(await getDatabasesPath(), dbName);

  Future<Database> _open() async {
    return openDatabase(
      await path,
      version: dbVersion,
      // SQLite ignores foreign keys unless this is turned on for every connection.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // A batch sends many statements together, which is faster and all-or-nothing.
    final batch = db.batch();
    DbSchema.createAll(batch);
    await batch.commit(noResult: true);
  }

  /// sqflite runs this inside a transaction, so a failed upgrade changes nothing.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await DbSchema.migrateToV2(db);
    if (oldVersion < 3) await DbSchema.migrateToV3(db);
  }

  /// "Delete all data": empties every table in one transaction and inserts
  /// the default categories again. Ids start from 1 again afterwards.
  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Children first, so foreign keys never block a delete.
      for (final t in [
        tRecurringInstallments,
        tTransactions,
        tBudgets,
        tMerchantRules,
        tDetectedSms,
        tRecurringPayments,
        tIgnoredSenders,
        tOwnAccounts,
        tCategories,
      ]) {
        await txn.delete(t);
      }
      await txn.delete('sqlite_sequence');
      await DbSchema.insertMissingDefaults(txn);
    });
  }

  /// Closes the database. The next `database` call opens it again.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
