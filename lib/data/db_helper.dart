import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'default_categories.dart';

/// Opens the single SQLite database and creates the tables on first run.
///
/// Repos call `DbHelper.instance.database` to get the open database.
/// It is a "singleton": there is only ever one DbHelper object in the app.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  static const String dbName = 'expense_tracker.db';
  static const int dbVersion = 1;

  // Table names, used by the repos so the spelling lives in one place.
  static const String tCategories = 'categories';
  static const String tTransactions = 'transactions';
  static const String tBudgets = 'budgets';
  static const String tDetectedSms = 'detected_sms';
  static const String tMerchantRules = 'merchant_rules';

  Database? _db;

  /// Returns the open database, opening it the first time it is needed.
  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      join(dir, dbName),
      version: dbVersion,
      // SQLite ignores foreign keys unless this is turned on for every connection.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // A batch sends many statements together, which is faster and all-or-nothing.
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE $tCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE $tDetectedSms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        merchant TEXT,
        account_last4 TEXT,
        payment_mode TEXT,
        guessed_category_id INTEGER
          REFERENCES $tCategories(id) ON DELETE SET NULL,
        received_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'saved', 'ignored'))
      )
    ''');

    batch.execute('''
      CREATE TABLE $tTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        category_id INTEGER NOT NULL
          REFERENCES $tCategories(id) ON DELETE RESTRICT,
        payment_mode TEXT NOT NULL,
        date_time TEXT NOT NULL,
        note TEXT,
        merchant TEXT,
        source TEXT NOT NULL DEFAULT 'manual'
          CHECK (source IN ('manual', 'sms')),
        sms_id INTEGER REFERENCES $tDetectedSms(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE $tBudgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        category_id INTEGER REFERENCES $tCategories(id) ON DELETE CASCADE,
        limit_paise INTEGER NOT NULL CHECK (limit_paise > 0),
        alert_80_sent INTEGER NOT NULL DEFAULT 0,
        alert_100_sent INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE $tMerchantRules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        category_id INTEGER NOT NULL
          REFERENCES $tCategories(id) ON DELETE CASCADE
      )
    ''');

    // Indexes make the common lookups fast.
    batch.execute(
        'CREATE INDEX idx_txn_date ON $tTransactions(date_time)');
    batch.execute(
        'CREATE INDEX idx_txn_category ON $tTransactions(category_id)');
    batch.execute(
        'CREATE INDEX idx_sms_status ON $tDetectedSms(status, received_at)');
    // One budget per month per category. IFNULL makes "overall" (NULL) unique too,
    // because SQLite normally treats every NULL as different.
    batch.execute('CREATE UNIQUE INDEX idx_budget_month_cat '
        'ON $tBudgets(month, IFNULL(category_id, 0))');

    for (final c in defaultCategories) {
      batch.insert(tCategories, c.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// Closes the database (used later by backup/restore).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
