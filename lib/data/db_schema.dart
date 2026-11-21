import 'package:sqflite/sqflite.dart';

import 'default_categories.dart';

/// Table names, used by the repos so the spelling lives in one place.
class Tables {
  Tables._();
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String detectedSms = 'detected_sms';
  static const String merchantRules = 'merchant_rules';
  static const String ignoredSenders = 'ignored_senders';
  static const String ownAccounts = 'own_accounts';
  static const String recurringPayments = 'recurring_payments';
  static const String recurringInstallments = 'recurring_installments';
}

/// The SQL that builds the database (PLAN.md section 7).
///
/// [createAll] builds a fresh version 2 database. [migrateToV2] upgrades a
/// version 1 database in place: it only ADDS columns, tables and missing
/// categories, so every existing row is kept.
class DbSchema {
  DbSchema._();

  // ---- Fresh install --------------------------------------------------------

  static void createAll(Batch batch) {
    batch.execute('''
      CREATE TABLE ${Tables.categories} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Created before detected_sms and transactions, which point to it.
    _createRecurringPayments(batch);

    batch.execute('''
      CREATE TABLE ${Tables.detectedSms} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        merchant TEXT,
        account_last4 TEXT,
        payment_mode TEXT,
        guessed_category_id INTEGER
          REFERENCES ${Tables.categories}(id) ON DELETE SET NULL,
        received_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'saved', 'ignored')),
        kind TEXT NOT NULL DEFAULT 'check'
          CHECK (kind IN ('bank', 'receipt', 'check')),
        is_self_transfer INTEGER NOT NULL DEFAULT 0,
        duplicate_of INTEGER
          REFERENCES ${Tables.detectedSms}(id) ON DELETE SET NULL,
        suggested_recurring_id INTEGER
          REFERENCES ${Tables.recurringPayments}(id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.transactions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
        category_id INTEGER NOT NULL
          REFERENCES ${Tables.categories}(id) ON DELETE RESTRICT,
        payment_mode TEXT NOT NULL,
        date_time TEXT NOT NULL,
        note TEXT,
        merchant TEXT,
        source TEXT NOT NULL DEFAULT 'manual'
          CHECK (source IN ('manual', 'sms')),
        sms_id INTEGER REFERENCES ${Tables.detectedSms}(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        recurring_id INTEGER
          REFERENCES ${Tables.recurringPayments}(id) ON DELETE SET NULL,
        refund_of_id INTEGER
          REFERENCES ${Tables.transactions}(id) ON DELETE SET NULL,
        is_self_transfer INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.budgets} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        category_id INTEGER REFERENCES ${Tables.categories}(id) ON DELETE CASCADE,
        limit_paise INTEGER NOT NULL CHECK (limit_paise > 0),
        alert_80_sent INTEGER NOT NULL DEFAULT 0,
        alert_100_sent INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.merchantRules} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE,
        category_id INTEGER NOT NULL
          REFERENCES ${Tables.categories}(id) ON DELETE CASCADE
      )
    ''');

    _createV2Tables(batch);

    // Indexes make the common lookups fast.
    batch.execute(
      'CREATE INDEX idx_txn_date ON ${Tables.transactions}(date_time)',
    );
    batch.execute(
      'CREATE INDEX idx_txn_category ON ${Tables.transactions}(category_id)',
    );
    batch.execute(
      'CREATE INDEX idx_sms_status '
      'ON ${Tables.detectedSms}(status, received_at)',
    );
    // One budget per month per category. IFNULL makes "overall" (NULL) unique
    // too, because SQLite normally treats every NULL as different.
    batch.execute(
      'CREATE UNIQUE INDEX idx_budget_month_cat '
      'ON ${Tables.budgets}(month, IFNULL(category_id, 0))',
    );

    for (final c in defaultCategories) {
      batch.insert(Tables.categories, c.toMap());
    }
  }

  // ---- Version 1 → 2 --------------------------------------------------------

  /// Runs inside the upgrade transaction, so it is all-or-nothing: if any
  /// step fails, the phone keeps the untouched version 1 database.
  static Future<void> migrateToV2(DatabaseExecutor db) async {
    // ALTER TABLE ... ADD COLUMN keeps every existing row; old rows get the
    // DEFAULT value (or NULL).
    const smsColumns = [
      "kind TEXT NOT NULL DEFAULT 'check'",
      'is_self_transfer INTEGER NOT NULL DEFAULT 0',
      'duplicate_of INTEGER',
      'suggested_recurring_id INTEGER',
    ];
    const txnColumns = [
      'recurring_id INTEGER',
      'refund_of_id INTEGER',
      'is_self_transfer INTEGER NOT NULL DEFAULT 0',
    ];
    for (final col in smsColumns) {
      await _addColumnIfMissing(db, Tables.detectedSms, col);
    }
    for (final col in txnColumns) {
      await _addColumnIfMissing(db, Tables.transactions, col);
    }

    final batch = db.batch();
    _createRecurringPayments(batch);
    _createV2Tables(batch);
    await batch.commit(noResult: true);

    await insertMissingDefaults(db);
  }

  /// Inserts each default category whose name + type is not in the table yet
  /// (case-insensitive), so nothing is ever duplicated.
  static Future<int> insertMissingDefaults(DatabaseExecutor db) async {
    final rows = await db.query(Tables.categories, columns: ['name', 'type']);
    final have = {
      for (final r in rows)
        '${(r['name'] as String).trim().toLowerCase()}|${r['type']}',
    };
    var added = 0;
    for (final c in defaultCategories) {
      if (have.contains('${c.name.toLowerCase()}|${c.type}')) continue;
      await db.insert(Tables.categories, c.toMap());
      added++;
    }
    return added;
  }

  /// Skips the column if it already exists (safe to run twice).
  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String columnDef,
  ) async {
    final name = columnDef.split(' ').first;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (info.any((c) => c['name'] == name)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
  }

  // ---- New in version 2 -----------------------------------------------------

  static void _createRecurringPayments(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.recurringPayments} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('bill', 'emi', 'chitti', 'fee')),
        amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
        category_id INTEGER NOT NULL
          REFERENCES ${Tables.categories}(id) ON DELETE RESTRICT,
        frequency TEXT NOT NULL DEFAULT 'monthly'
          CHECK (frequency IN ('monthly', 'weekly', 'yearly')),
        due_day INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        total_installments INTEGER,
        remind_days_before INTEGER NOT NULL DEFAULT 1,
        payment_mode TEXT NOT NULL,
        match_keyword TEXT,
        organiser_name TEXT,
        organiser_phone TEXT,
        chitti_received_paise INTEGER,
        chitti_received_date TEXT,
        notes TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static void _createV2Tables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.ignoredSenders} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.ownAccounts} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last4 TEXT NOT NULL UNIQUE,
        label TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.recurringInstallments} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recurring_id INTEGER NOT NULL
          REFERENCES ${Tables.recurringPayments}(id) ON DELETE CASCADE,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'paid', 'skipped')),
        paid_amount_paise INTEGER,
        transaction_id INTEGER
          REFERENCES ${Tables.transactions}(id) ON DELETE SET NULL,
        paid_at TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_inst_recurring '
      'ON ${Tables.recurringInstallments}(recurring_id, due_date)',
    );
  }
}
