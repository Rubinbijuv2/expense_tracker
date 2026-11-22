import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/db_helper.dart';
import 'package:expense_tracker/data/db_schema.dart';
import 'package:expense_tracker/data/default_categories.dart';
import 'package:expense_tracker/data/transaction_repo.dart';

/// Runs the real SQLite upgrade code (db_helper.dart + db_schema.dart) on a
/// real database file. The test database factory is set up in
/// flutter_test_config.dart.
///
/// The SQL below is the version 1 schema as it was shipped in build step 2.
/// Don't change it: it stands for the database on phones that installed v1.
const _v1Schema = [
  '''CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
    is_default INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE detected_sms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender TEXT NOT NULL,
    body TEXT NOT NULL,
    amount_paise INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
    merchant TEXT,
    account_last4 TEXT,
    payment_mode TEXT,
    guessed_category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    received_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
      CHECK (status IN ('pending', 'saved', 'ignored'))
  )''',
  '''CREATE TABLE transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
    type TEXT NOT NULL CHECK (type IN ('expense', 'income')),
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    payment_mode TEXT NOT NULL,
    date_time TEXT NOT NULL,
    note TEXT,
    merchant TEXT,
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'sms')),
    sms_id INTEGER REFERENCES detected_sms(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL
  )''',
  '''CREATE TABLE budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    month TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    limit_paise INTEGER NOT NULL CHECK (limit_paise > 0),
    alert_80_sent INTEGER NOT NULL DEFAULT 0,
    alert_100_sent INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE merchant_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword TEXT NOT NULL UNIQUE,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE
  )''',
  'CREATE INDEX idx_txn_date ON transactions(date_time)',
  'CREATE INDEX idx_txn_category ON transactions(category_id)',
  'CREATE INDEX idx_sms_status ON detected_sms(status, received_at)',
  'CREATE UNIQUE INDEX idx_budget_month_cat '
      'ON budgets(month, IFNULL(category_id, 0))',
];

/// Writes a version 1 database file with some user data in it, the way an
/// old phone would have it, then closes it.
Future<void> _createV1Database(String path) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        for (final sql in _v1Schema) {
          await db.execute(sql);
        }
        // Version 1 had only the first 10 default categories.
        for (final c in defaultCategories.take(10)) {
          await db.insert('categories', c.toMap());
        }
      },
    ),
  );
  // id 11: a category the user made.
  await db.insert('categories', {
    'name': 'Gym',
    'icon': 'fitness_center',
    'color': 0xFF00897B,
    'type': 'expense',
    'is_default': 0,
  });
  await db.insert('detected_sms', {
    'sender': 'AX-HDFCBK',
    'body': 'Rs 250.00 debited from a/c XX1234 to SWIGGY',
    'amount_paise': 25000,
    'type': 'expense',
    'merchant': 'SWIGGY',
    'account_last4': '1234',
    'payment_mode': 'UPI',
    'guessed_category_id': 1,
    'received_at': '2026-01-10T13:05:00.000',
    'status': 'saved',
  });
  await db.insert('transactions', {
    'amount_paise': 25000,
    'type': 'expense',
    'category_id': 1,
    'payment_mode': 'UPI',
    'date_time': '2026-01-10T13:05:00.000',
    'note': 'Lunch',
    'merchant': 'SWIGGY',
    'source': 'sms',
    'sms_id': 1,
    'created_at': '2026-01-10T13:06:00.000',
  });
  await db.insert('transactions', {
    'amount_paise': 150000,
    'type': 'expense',
    'category_id': 11,
    'payment_mode': 'Cash',
    'date_time': '2026-01-12T07:00:00.000',
    'source': 'manual',
    'created_at': '2026-01-12T07:01:00.000',
  });
  await db.insert('budgets', {
    'month': '2026-01',
    'category_id': null,
    'limit_paise': 2000000,
    'alert_80_sent': 1,
  });
  await db.insert('merchant_rules', {'keyword': 'swiggy', 'category_id': 1});
  await db.close();
}

/// Column names of every table, plus the index names: the "shape" of a
/// database, used to compare an upgraded database with a fresh one.
Future<Map<String, List<String>>> _shape(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY name",
  );
  final shape = <String, List<String>>{};
  for (final t in tables) {
    final name = t['name'] as String;
    final cols = await db.rawQuery('PRAGMA table_info($name)');
    shape[name] = [for (final c in cols) c['name'] as String]..sort();
  }
  final indexes = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  shape['(indexes)'] = [for (final i in indexes) i['name'] as String];
  return shape;
}

void main() {
  final helper = DbHelper.instance;

  // Every test starts with no database file at all.
  setUp(() async {
    await helper.close();
    await databaseFactory.deleteDatabase(await helper.path);
  });
  tearDownAll(() => helper.close());

  test(
    'a fresh install creates version 3 with the default categories',
    () async {
      final db = await helper.database;
      expect(await db.getVersion(), DbHelper.dbVersion);
      final count = await db.rawQuery('SELECT COUNT(*) AS n FROM categories');
      expect(count.first['n'], defaultCategories.length);
    },
  );

  group('version 1 → 3 upgrade', () {
    late Database db;

    setUp(() async {
      await _createV1Database(await helper.path);
      db = await helper.database; // opening it runs the upgrade
    });

    test('the database is now version 3', () async {
      expect(await db.getVersion(), 3);
    });

    test('keeps every old transaction with its values', () async {
      final txns = await TransactionRepo().getAll();
      expect(txns, hasLength(2));
      final lunch = txns.firstWhere((t) => t.note == 'Lunch');
      expect(lunch.amountPaise, 25000);
      expect(lunch.categoryId, 1);
      expect(lunch.merchant, 'SWIGGY');
      expect(lunch.source, 'sms');
      expect(lunch.smsId, 1);
      expect(lunch.dateTime, DateTime(2026, 1, 10, 13, 5));
      // New v2 columns get their defaults.
      expect(lunch.isSelfTransfer, isFalse);
      expect(lunch.recurringId, isNull);
      expect(lunch.refundOfId, isNull);
      // The user's own category is still linked.
      expect(txns.firstWhere((t) => t.note == null).categoryId, 11);
    });

    test(
      'old detected SMS rows get kind, self-transfer and source defaults',
      () async {
        final rows = await db.query('detected_sms');
        expect(rows, hasLength(1));
        final sms = rows.first;
        expect(sms['body'], 'Rs 250.00 debited from a/c XX1234 to SWIGGY');
        expect(sms['status'], 'saved');
        expect(sms['kind'], 'check');
        expect(sms['is_self_transfer'], 0);
        expect(sms['duplicate_of'], isNull);
        expect(sms['source'], 'sms'); // v3: old rows all came from SMS
        expect(sms['source_app'], isNull);
      },
    );

    test('keeps budgets, alert flags and merchant rules', () async {
      final budget = (await db.query('budgets')).single;
      expect(budget['month'], '2026-01');
      expect(budget['category_id'], isNull);
      expect(budget['limit_paise'], 2000000);
      expect(budget['alert_80_sent'], 1);
      final rule = (await db.query('merchant_rules')).single;
      expect(rule['keyword'], 'swiggy');
      expect(rule['category_id'], 1);
    });

    test('adds the new default categories once, keeping old ids', () async {
      final rows = await db.query('categories', orderBy: 'id');
      // 10 old defaults + the user's Gym + the v2 defaults.
      expect(rows, hasLength(defaultCategories.length + 1));
      for (var i = 0; i < 10; i++) {
        expect(rows[i]['id'], i + 1);
        expect(rows[i]['name'], defaultCategories[i].name);
      }
      expect(rows[10]['name'], 'Gym');
      final keys = {for (final r in rows) '${r['name']}|${r['type']}'};
      expect(keys, hasLength(rows.length), reason: 'no duplicates');
    });

    test('running the default-category step again adds nothing', () async {
      expect(await DbSchema.insertMissingDefaults(db), 0);
    });

    test(
      'has the same tables, columns and indexes as a fresh install',
      () async {
        final upgraded = await _shape(db);
        await helper.close();
        await databaseFactory.deleteDatabase(await helper.path);
        final fresh = await _shape(await helper.database);
        expect(upgraded, fresh);
      },
    );

    test('the new tables work and foreign keys are on', () async {
      final rpId = await db.insert('recurring_payments', {
        'name': 'Bike EMI',
        'type': 'emi',
        'amount_paise': 350000,
        'category_id': 1,
        'due_day': 5,
        'start_date': '2026-01-05T00:00:00.000',
        'payment_mode': 'UPI',
        'created_at': '2026-01-01T00:00:00.000',
      });
      await db.insert('recurring_installments', {
        'recurring_id': rpId,
        'due_date': '2026-02-05T00:00:00.000',
        'transaction_id': 1,
      });
      // Deleting the transaction clears the link (ON DELETE SET NULL).
      await db.delete('transactions', where: 'id = ?', whereArgs: [1]);
      final inst = (await db.query('recurring_installments')).single;
      expect(inst['transaction_id'], isNull);
    });
  });

  test('a version 2 database also upgrades to 3', () async {
    final path = await helper.path;
    await _createV1Database(path);
    // Bring it to version 2 only, like a phone that skipped the v3 update.
    final v2 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, _, _) => DbSchema.migrateToV2(db),
      ),
    );
    final v2Cols = await v2.rawQuery('PRAGMA table_info(detected_sms)');
    expect(v2Cols.map((c) => c['name']), isNot(contains('source')));
    await v2.close();

    final db = await helper.database;
    expect(await db.getVersion(), 3);
    final sms = (await db.query('detected_sms')).single;
    expect(sms['kind'], 'check');
    expect(sms['source'], 'sms');
    expect(await db.query('transactions'), hasLength(2));
  });
}
