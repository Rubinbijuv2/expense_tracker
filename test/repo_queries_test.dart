import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/budget_repo.dart';
import 'package:expense_tracker/data/category_repo.dart';
import 'package:expense_tracker/data/db_helper.dart';
import 'package:expense_tracker/data/detected_sms_repo.dart';
import 'package:expense_tracker/data/merchant_rule_repo.dart';
import 'package:expense_tracker/data/recurring_installment_repo.dart';
import 'package:expense_tracker/data/transaction_repo.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/detected_sms.dart';
import 'package:expense_tracker/models/recurring_installment.dart';
import 'package:expense_tracker/models/transaction_filter.dart';
import 'package:expense_tracker/models/transaction_model.dart';

/// The main repo queries, run on a real SQLite database (fresh v3 install).
/// The test database factory is set up in flutter_test_config.dart.
void main() {
  final helper = DbHelper.instance;
  final txns = TransactionRepo();
  final cats = CategoryRepo();
  final budgets = BudgetRepo();
  final sms = DetectedSmsRepo();
  late int food, travel, salary;

  TransactionModel txn(
    int paise,
    DateTime at, {
    String type = 'expense',
    int? category,
    String mode = 'UPI',
    String? note,
    String? merchant,
    bool self = false,
  }) => TransactionModel(
    amountPaise: paise,
    type: type,
    categoryId: category ?? (type == 'income' ? salary : food),
    paymentMode: mode,
    dateTime: at,
    note: note,
    merchant: merchant,
    isSelfTransfer: self,
  );

  DetectedSms detected(
    int paise,
    DateTime at, {
    String sender = 'AX-HDFCBK',
    String type = 'expense',
    String kind = 'bank',
    String? merchant,
    String source = 'sms',
    String status = 'pending',
  }) => DetectedSms(
    sender: sender,
    body: 'Rs $paise at $at from $sender ($kind)',
    amountPaise: paise,
    type: type,
    merchant: merchant,
    receivedAt: at,
    kind: kind,
    source: source,
    status: status,
  );

  // A fresh database for every test.
  setUp(() async {
    await helper.close();
    await databaseFactory.deleteDatabase(await helper.path);
    food = (await cats.getByName('Food'))!.id!;
    travel = (await cats.getByName('Travel'))!.id!;
    salary = (await cats.getByType('income')).first.id!;
  });
  tearDownAll(() => helper.close());

  group('TransactionRepo', () {
    test('insert, getById, update and delete', () async {
      final id = await txns.insert(txn(12345, DateTime(2026, 3, 4, 10)));
      final saved = await txns.getById(id);
      expect(saved!.amountPaise, 12345);
      expect(saved.dateTime, DateTime(2026, 3, 4, 10));

      await txns.update(saved.copyWith(amountPaise: 999, note: 'Tea'));
      expect((await txns.getById(id))!.note, 'Tea');
      expect((await txns.getById(id))!.amountPaise, 999);

      expect(await txns.delete(id), 1);
      expect(await txns.getById(id), isNull);
    });

    test('getAll and recent are newest first', () async {
      await txns.insert(txn(100, DateTime(2026, 3, 1)));
      await txns.insert(txn(300, DateTime(2026, 3, 3)));
      await txns.insert(txn(200, DateTime(2026, 3, 2)));
      final all = await txns.getAll();
      expect(all.map((t) => t.amountPaise), [300, 200, 100]);
      expect((await txns.recent(2)).map((t) => t.amountPaise), [300, 200]);
    });

    test('month totals skip self transfers and other months', () async {
      final march = DateTime(2026, 3);
      await txns.insert(txn(10000, DateTime(2026, 3, 1))); // first moment
      await txns.insert(txn(5000, DateTime(2026, 3, 31, 23, 59)));
      await txns.insert(txn(7000, DateTime(2026, 3, 15), category: travel));
      await txns.insert(txn(99999, DateTime(2026, 3, 10), self: true));
      await txns.insert(txn(88888, DateTime(2026, 4, 1))); // April
      await txns.insert(txn(77777, DateTime(2026, 2, 28, 23, 59))); // Feb
      await txns.insert(txn(500000, DateTime(2026, 3, 1), type: 'income'));

      expect(await txns.totalByType(march, 'expense'), 22000);
      expect(await txns.totalByType(march, 'income'), 500000);
      expect(await txns.totalByType(DateTime(2025, 1), 'expense'), 0);
      expect(await txns.totalForCategory(march, food), 15000);

      final byCat = await txns.totalsByCategory(march, 'expense');
      expect(byCat.map((c) => c.categoryId), [food, travel]); // biggest first
      expect(byCat.map((c) => c.totalPaise), [15000, 7000]);

      expect(await txns.getForMonth(march), hasLength(5));
    });

    test('search uses text, filters and treats % literally', () async {
      await txns.insert(txn(1000, DateTime(2026, 3, 1), merchant: 'Swiggy'));
      await txns.insert(txn(2000, DateTime(2026, 3, 2), note: '50% off pizza'));
      await txns.insert(
        txn(3000, DateTime(2026, 3, 3), note: '500 off', mode: 'Cash'),
      );
      await txns.insert(
        txn(4000, DateTime(2026, 3, 9), category: travel, mode: 'Card'),
      );

      Future<List<int>> amounts(TransactionFilter f) async =>
          (await txns.search(f)).map((t) => t.amountPaise).toList();

      expect(await amounts(const TransactionFilter()), [
        4000,
        3000,
        2000,
        1000,
      ]);
      expect(await amounts(const TransactionFilter(query: 'SWIG')), [1000]);
      expect(await amounts(const TransactionFilter(query: '50%')), [2000]);
      expect(await amounts(TransactionFilter(categoryIds: {travel})), [4000]);
      expect(
        await amounts(const TransactionFilter(paymentModes: {'Cash', 'Card'})),
        [4000, 3000],
      );
      expect(
        await amounts(const TransactionFilter(minPaise: 2000, maxPaise: 3000)),
        [3000, 2000],
      );
      // "to" includes the whole last day.
      expect(
        await amounts(
          TransactionFilter(
            from: DateTime(2026, 3, 2),
            to: DateTime(2026, 3, 3),
          ),
        ),
        [3000, 2000],
      );
    });

    test('existsSimilar matches amount + merchant within 2 minutes', () async {
      final at = DateTime(2026, 3, 5, 12);
      await txns.insert(txn(25000, at, merchant: 'Zomato'));
      expect(
        await txns.existsSimilar(
          25000,
          'ZOMATO',
          at.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
      expect(
        await txns.existsSimilar(
          25000,
          'Zomato',
          at.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
      expect(await txns.existsSimilar(25001, 'Zomato', at), isFalse);
    });
  });

  group('CategoryRepo', () {
    test('getByName ignores case; getByType filters', () async {
      expect((await cats.getByName('fOOd'))!.id, food);
      final income = await cats.getByType('income');
      expect(income, isNotEmpty);
      expect(income.every((c) => c.isIncome), isTrue);
    });

    test('a used category cannot be deleted (ON DELETE RESTRICT)', () async {
      expect(await cats.isUsed(travel), isFalse);
      await txns.insert(txn(100, DateTime(2026, 3, 1), category: travel));
      expect(await cats.isUsed(travel), isTrue);
      expect(() => cats.delete(travel), throwsA(isA<DatabaseException>()));
    });
  });

  group('BudgetRepo', () {
    test('setLimit creates, then updates and resets the alerts', () async {
      await budgets.setLimit('2026-03', null, 1000000);
      final first = (await budgets.getOverall('2026-03'))!;
      await budgets.update(first.copyWith(alert80Sent: true));

      await budgets.setLimit('2026-03', null, 1500000);
      final all = await budgets.getForMonth('2026-03');
      expect(all, hasLength(1));
      expect(all.single.limitPaise, 1500000);
      expect(all.single.alert80Sent, isFalse);
    });

    test('only one overall budget per month (unique index)', () async {
      await budgets.setLimit('2026-03', null, 1000000);
      expect(
        () => budgets.insert(const Budget(month: '2026-03', limitPaise: 500)),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'getForMonth lists overall first; copy from the latest earlier month',
      () async {
        await budgets.setLimit('2026-01', travel, 50000);
        await budgets.setLimit('2026-02', food, 300000);
        await budgets.setLimit('2026-02', null, 2000000);
        await budgets.setLimit('2026-04', food, 400000); // already there

        final feb = await budgets.getForMonth('2026-02');
        expect(feb.first.isOverall, isTrue);

        expect(await budgets.latestMonthBefore('2026-04'), '2026-02');
        expect(await budgets.copyFromLatestBefore('2026-04'), 1);
        final april = await budgets.getForMonth('2026-04');
        expect(april.map((b) => b.limitPaise), [2000000, 400000]);
        expect(await budgets.copyFromLatestBefore('2025-12'), 0);
      },
    );
  });

  group('DetectedSmsRepo', () {
    final at = DateTime(2026, 3, 5, 12);

    test('pending list, count, status changes and ignore by sender', () async {
      final a = await sms.insert(detected(100, at));
      await sms.insert(detected(200, at.add(const Duration(hours: 1))));
      await sms.insert(detected(300, at, sender: 'VM-SBIUPI'));
      await sms.insert(detected(400, at, status: 'saved'));

      expect(await sms.countPending(), 3);
      expect((await sms.getPending()).first.amountPaise, 200); // newest first
      expect(await sms.existsByBody((await sms.getById(a))!.body), isTrue);

      expect(await sms.ignorePendingFromSender(' ax-hdfcbk '), hasLength(2));
      expect(await sms.countPending(), 1);
      await sms.updateStatus(a, 'pending');
      expect(await sms.countPending(), 2);
      expect(await sms.ignoreAllPending(), 2);
      expect(await sms.countPending(), 0);
    });

    test('findPairPartner picks the closest match of the right type', () async {
      await sms.insert(
        detected(
          5000,
          at.add(const Duration(minutes: 1)),
          kind: 'receipt',
          type: 'income',
        ),
      );
      final right = await sms.insert(
        detected(5000, at.add(const Duration(minutes: 5)), kind: 'receipt'),
      );
      await sms.insert(
        detected(5000, at.add(const Duration(minutes: 10)), kind: 'receipt'),
      );
      await sms.insert(
        detected(5000, at.add(const Duration(minutes: 31)), kind: 'receipt'),
      );

      final found = await sms.findPairPartner(5000, 'receipt', 'expense', at);
      expect(found!.id, right);

      // Once paired, it is no longer offered.
      final bank = await sms.insert(detected(5000, at));
      await sms.setDuplicateOf(right, bank);
      final next = await sms.findPairPartner(5000, 'receipt', 'expense', at);
      expect(next!.receivedAt, at.add(const Duration(minutes: 10)));
    });

    test('existsSimilarPending ignores payment app notifications', () async {
      await sms.insert(
        detected(
          700,
          at,
          merchant: 'Uber',
          source: 'notification',
          sender: 'Google Pay',
        ),
      );
      expect(await sms.existsSimilarPending(700, 'uber', at), isFalse);
      expect(
        await sms.existsRecentFromApp(
          'Google Pay',
          700,
          'Rs 700 at $at from Google Pay (bank)',
          at,
        ),
        isTrue,
      );
      await sms.insert(detected(700, at, merchant: 'Uber'));
      expect(await sms.existsSimilarPending(700, 'uber', at), isTrue);
    });
  });

  test('MerchantRuleRepo.upsert replaces the category of a keyword', () async {
    final rules = MerchantRuleRepo();
    await rules.upsert('  Swiggy ', food);
    await rules.upsert('swiggy', travel);
    final all = await rules.getAll();
    expect(all, hasLength(1));
    expect((await rules.findByKeyword('SWIGGY'))!.categoryId, travel);
  });

  test('RecurringInstallmentRepo.deletePending keeps paid ones', () async {
    final db = await helper.database;
    final rpId = await db.insert(DbHelper.tRecurringPayments, {
      'name': 'Rent',
      'type': 'bill',
      'amount_paise': 1000000,
      'category_id': food,
      'due_day': 1,
      'payment_mode': 'UPI',
      'start_date': '2026-01-01T00:00:00.000',
      'created_at': '2026-01-01T00:00:00.000',
    });
    final inst = RecurringInstallmentRepo();
    await inst.insertPending(rpId, [
      DateTime(2026, 2, 1),
      DateTime(2026, 1, 1),
    ]);
    final first = (await inst.getFor(rpId)).first;
    expect(first.dueDate, DateTime(2026, 1, 1)); // oldest first
    await inst.update(
      RecurringInstallment(
        id: first.id,
        recurringId: rpId,
        dueDate: first.dueDate,
        status: 'paid',
        paidAmountPaise: 1000000,
        paidAt: DateTime(2026, 1, 1),
      ),
    );
    expect(await inst.deletePending(rpId), 1);
    expect((await inst.getAll()).single.isPaid, isTrue);
  });

  test('resetAllData empties tables and restores default categories', () async {
    await txns.insert(txn(100, DateTime(2026, 3, 1)));
    await budgets.setLimit('2026-03', null, 1000);
    await helper.resetAllData();
    expect(await txns.getAll(), isEmpty);
    expect(await budgets.getForMonth('2026-03'), isEmpty);
    expect((await cats.getByName('Food'))!.id, 1); // ids start again
  });
}
