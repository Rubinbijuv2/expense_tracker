import 'package:expense_tracker/data/category_repo.dart';
import 'package:expense_tracker/data/detected_sms_repo.dart';
import 'package:expense_tracker/data/ignored_sender_repo.dart';
import 'package:expense_tracker/data/merchant_rule_repo.dart';
import 'package:expense_tracker/data/own_account_repo.dart';
import 'package:expense_tracker/data/transaction_repo.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/detected_sms.dart';
import 'package:expense_tracker/models/merchant_rule.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/detected_sms_provider.dart';
import 'package:expense_tracker/services/budget_alert_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:expense_tracker/services/sms_action_service.dart';
import 'package:expense_tracker/services/sms_recheck.dart';
import 'package:expense_tracker/services/sms_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Fake repos: keep rows in lists instead of SQLite --------------------
// They extend the real repos and override only what SmsService uses,
// so the real database is never opened.

class FakeSmsRepo extends DetectedSmsRepo {
  final List<DetectedSms> rows = [];

  @override
  Future<int> insert(DetectedSms sms) async {
    rows.add(sms.copyWith(id: rows.length + 1));
    return rows.length;
  }

  @override
  Future<bool> existsByBody(String body) async =>
      rows.any((r) => r.body == body);

  @override
  Future<DetectedSms?> getById(int id) async =>
      rows.where((r) => r.id == id).firstOrNull;

  @override
  Future<int> update(DetectedSms sms) async {
    final i = rows.indexWhere((r) => r.id == sms.id);
    rows[i] = sms;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    rows.removeWhere((r) => r.id == id);
    return 1;
  }

  @override
  Future<int> updateStatus(int id, String status) async {
    final i = rows.indexWhere((r) => r.id == id);
    rows[i] = rows[i].copyWith(status: status);
    return 1;
  }

  @override
  Future<List<DetectedSms>> getPending({int? limit}) async =>
      rows.where((r) => r.isPending).toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

  @override
  Future<int> setDuplicateOf(int id, int? otherId) async {
    final i = rows.indexWhere((r) => r.id == id);
    rows[i] = otherId == null
        ? rows[i].copyWith(clearDuplicateOf: true)
        : rows[i].copyWith(duplicateOf: otherId);
    return 1;
  }

  @override
  Future<DetectedSms?> findPairPartner(
    int amountPaise,
    String otherKind,
    DateTime at, {
    Duration window = const Duration(minutes: 30),
  }) async => rows
      .where(
        (r) =>
            r.isPending &&
            r.kind == otherKind &&
            r.amountPaise == amountPaise &&
            r.duplicateOf == null &&
            !r.isSelfTransfer &&
            r.receivedAt.difference(at).abs() <= window,
      )
      .firstOrNull;

  @override
  Future<bool> existsSimilarPending(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async => rows.any(
    (r) =>
        r.isPending &&
        r.amountPaise == amountPaise &&
        r.merchant?.toLowerCase() == merchant.toLowerCase() &&
        r.receivedAt.difference(at).abs() <= window,
  );
}

class FakeTxnRepo extends TransactionRepo {
  /// (amount, merchant, time) of existing transactions.
  final List<(int, String, DateTime)> existing = [];
  final List<TransactionModel> inserted = [];

  @override
  Future<int> insert(TransactionModel txn) async {
    inserted.add(txn);
    return inserted.length;
  }

  @override
  Future<bool> existsSimilar(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async => existing.any(
    (t) =>
        t.$1 == amountPaise &&
        t.$2.toLowerCase() == merchant.toLowerCase() &&
        t.$3.difference(at).abs() <= window,
  );
}

class FakeRuleRepo extends MerchantRuleRepo {
  final List<MerchantRule> rules = [];

  @override
  Future<List<MerchantRule>> getAll() async => rules;
}

class FakeIgnoredRepo extends IgnoredSenderRepo {
  final Set<String> senders = {};

  @override
  Future<Set<String>> getAll() async => senders;
}

class FakeOwnRepo extends OwnAccountRepo {
  final Set<String> last4 = {};

  @override
  Future<Set<String>> getAllLast4() async => last4;
}

/// Records budget checks instead of touching the database.
class FakeBudgetAlerts extends BudgetAlertService {
  FakeBudgetAlerts() : super(notify: (_, _, _) async {});
  final List<TransactionModel> checked = [];

  @override
  Future<void> checkAfterSave(TransactionModel txn) async => checked.add(txn);
}

class FakeCategoryRepo extends CategoryRepo {
  final List<CategoryModel> cats = const [
    CategoryModel(
      id: 1,
      name: 'Food',
      icon: 'restaurant',
      color: 0,
      type: 'expense',
    ),
    CategoryModel(
      id: 2,
      name: 'Travel',
      icon: 'directions_car',
      color: 0,
      type: 'expense',
    ),
    CategoryModel(
      id: 9,
      name: 'Salary',
      icon: 'account_balance_wallet',
      color: 0,
      type: 'income',
    ),
    CategoryModel(
      id: 10,
      name: 'Others',
      icon: 'category',
      color: 0,
      type: 'expense',
    ),
    CategoryModel(
      id: 12,
      name: 'Vehicle',
      icon: 'two_wheeler',
      color: 0,
      type: 'expense',
    ),
    CategoryModel(
      id: 16,
      name: 'Money received',
      icon: 'payments',
      color: 0,
      type: 'income',
    ),
  ];

  @override
  Future<CategoryModel?> getById(int id) async =>
      cats.where((c) => c.id == id).firstOrNull;

  @override
  Future<CategoryModel?> getByName(String name) async =>
      cats.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;

  @override
  Future<List<CategoryModel>> getByType(String type) async =>
      cats.where((c) => c.type == type).toList();
}

const swiggySender = 'AX-HDFCBK';
const swiggyBody =
    'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA '
    'swiggy@axisbank (UPI Ref No 632412345678). Not you? Call 18002586161';

void main() {
  late FakeSmsRepo smsRepo;
  late FakeTxnRepo txnRepo;
  late FakeRuleRepo ruleRepo;
  late FakeIgnoredRepo ignoredRepo;
  late FakeOwnRepo ownRepo;
  late SmsService service;
  final now = DateTime(2026, 11, 20, 13, 5);

  setUp(() {
    smsRepo = FakeSmsRepo();
    txnRepo = FakeTxnRepo();
    ruleRepo = FakeRuleRepo();
    ignoredRepo = FakeIgnoredRepo();
    ownRepo = FakeOwnRepo();
    service = SmsService(
      smsRepo: smsRepo,
      transactionRepo: txnRepo,
      ruleRepo: ruleRepo,
      categoryRepo: FakeCategoryRepo(),
      ignoredRepo: ignoredRepo,
      ownRepo: ownRepo,
    );
  });

  // Shorthand: run the pipeline and return the saved row (or null).
  Future<DetectedSms?> process(String sender, String body, DateTime at) async =>
      (await service.processMessage(sender, body, at)).saved;

  Future<String?> reason(String sender, String body, DateTime at) async =>
      (await service.processMessage(sender, body, at)).ignoredReason;

  group('SmsService.processMessage', () {
    test('bank SMS is saved as pending with a guessed category', () async {
      final saved = await process(swiggySender, swiggyBody, now);

      expect(saved, isNotNull);
      expect(saved!.id, 1);
      expect(saved.status, 'pending');
      expect(saved.amountPaise, 45000);
      expect(saved.type, 'expense');
      expect(saved.merchant, 'Swiggy');
      expect(saved.paymentMode, 'UPI');
      expect(saved.accountLast4, '1234');
      expect(saved.guessedCategoryId, 1); // Food
      expect(saved.receivedAt, now);
      expect(smsRepo.rows, hasLength(1));
    });

    test('SMS from a phone number is not stored', () async {
      expect(
        await reason(
          '9876543210',
          'Bro I sent you Rs 500 for the movie tickets',
          now,
        ),
        'not a bank sender',
      );
      expect(smsRepo.rows, isEmpty);
    });

    test('OTP from a bank is not stored', () async {
      expect(
        await reason(
          swiggySender,
          '482913 is the OTP for your transaction of Rs.450.00 at SWIGGY.',
          now,
        ),
        'OTP message',
      );
      expect(smsRepo.rows, isEmpty);
    });

    test('other ignore reasons', () async {
      expect(
        await reason(
          'VM-AMAZON',
          'Get 10% cashback on orders above Rs.999! Shop now on Amazon.',
          now,
        ),
        'promotional message',
      );
      expect(
        await reason(
          'JD-ICICIB',
          'Rs 5,000 will be debited from your A/c XX901 on 25-11-26 for SIP.',
          now,
        ),
        'future debit (not paid yet)',
      );
      expect(
        await reason('AX-HDFCBK', 'Your money was debited.', now),
        'no amount found',
      );
      expect(await reason('AX-HDFCBK', '   ', now), 'empty SMS');
      expect(smsRepo.rows, isEmpty);
    });

    test('the same SMS text twice is stored once', () async {
      await process(swiggySender, swiggyBody, now);
      expect(
        await reason(
          swiggySender,
          swiggyBody,
          now.add(const Duration(hours: 1)),
        ),
        'duplicate (same SMS already stored)',
      );
      expect(smsRepo.rows, hasLength(1));
    });

    test('same amount + merchant within 2 minutes is a duplicate', () async {
      await process(swiggySender, swiggyBody, now);
      // A different SMS (from the UPI app) about the same payment.
      expect(
        await reason(
          'VM-PAYTMB',
          'Rs.450 paid to swiggy@axisbank from Paytm a/c 918XXX. UPI Ref 1',
          now.add(const Duration(seconds: 90)),
        ),
        'duplicate (matches a detected SMS within 2 minutes)',
      );
    });

    test('same amount + merchant 3 minutes later is NOT a duplicate', () async {
      await process(swiggySender, swiggyBody, now);
      final second = await process(
        'VM-PAYTMB',
        'Rs.450 paid to swiggy@axisbank from Paytm a/c 918XXX. UPI Ref 1',
        now.add(const Duration(minutes: 3)),
      );
      expect(second, isNotNull);
    });

    test('matches an existing transaction within 2 minutes', () async {
      txnRepo.existing.add((
        45000,
        'swiggy',
        now.subtract(const Duration(minutes: 1)),
      ));
      expect(
        await reason(swiggySender, swiggyBody, now),
        'duplicate (matches a transaction within 2 minutes)',
      );
    });

    test('a learned merchant rule beats the keyword map', () async {
      ruleRepo.rules.add(const MerchantRule(keyword: 'swiggy', categoryId: 2));
      final saved = await process(swiggySender, swiggyBody, now);
      expect(saved!.guessedCategoryId, 2);
    });

    test('income gets the default income category (Money received)', () async {
      final saved = await process(
        'VM-ICICIB',
        'Dear Customer, Rs.649.00 received in your account XX901 from '
            'rahul@okhdfcbank on 15-11-26. UPI Ref 632477778888',
        now,
      );
      expect(saved!.type, 'income');
      expect(saved.guessedCategoryId, 16);
    });

    test('unknown expense merchant falls back to Others', () async {
      final saved = await process(
        'AD-AXISBK',
        'INR 300.00 spent on AXIS Bank Card XX4321 on 18-11-26 at RAMESH STORES.',
        now,
      );
      expect(saved!.guessedCategoryId, 10);
    });
  });

  group('notification text', () {
    DetectedSms sms(String type, int paise, String merchant) => DetectedSms(
      sender: 'AX-HDFCBK',
      body: 'x',
      amountPaise: paise,
      type: type,
      merchant: merchant,
      receivedAt: now,
    );

    test('expense', () {
      expect(
        NotificationService.detectedText(sms('expense', 45000, 'Swiggy')),
        '₹450 paid to Swiggy — tap to add',
      );
    });

    test('income keeps paise when not zero', () {
      expect(
        NotificationService.detectedText(sms('income', 64950, 'Rahul')),
        '₹649.50 received from Rahul — tap to add',
      );
    });
  });

  test('a detected SMS becomes an sms-sourced transaction', () {
    final s = DetectedSms(
      id: 7,
      sender: 'AX-HDFCBK',
      body: 'x',
      amountPaise: 45000,
      type: 'expense',
      merchant: 'Swiggy',
      paymentMode: null,
      receivedAt: now,
    );
    final t = DetectedSmsProvider.toTransaction(s, 1);
    expect(t.source, 'sms');
    expect(t.smsId, 7);
    expect(t.amountPaise, 45000);
    expect(t.dateTime, now);
    expect(t.paymentMode, 'UPI'); // default when the SMS didn't say
  });

  // ---- Step 6b ---------------------------------------------------------------

  const vaahanReceipt =
      'Payment received for Vehicle KL07AB1234 PUC fee Rs 120.00. '
      'Transaction ID VH998877. Thank you, Team Vaahan';
  const vaahanBank =
      'Rs.120.00 debited from A/c XX1234 on 20-11-26 to VPA '
      'parivahan.pay@sbi UPI Ref No 632400001200';
  const ownTransfer =
      'Rs.5,000.00 sent from A/c XX1234 to A/c XX5678 via IMPS on 20-11-26. '
      'Ref No 445566';

  group('step 6b pipeline', () {
    test('kind is stored on the pending row', () async {
      final bank = await process(swiggySender, swiggyBody, now);
      expect(bank!.kind, 'bank');
      expect(bank.kindLabel, 'Bank');
      final receipt = await process('AD-VAAHAN-S', vaahanReceipt, now);
      expect(receipt!.kind, 'receipt');
      expect(receipt.type, 'expense'); // "payment received" = shop got it
      expect(receipt.guessedCategoryId, 12); // Vehicle
    });

    test('a sender on the ignore list is not stored', () async {
      ignoredRepo.senders.add('AX-HDFCBK');
      expect(
        await reason(swiggySender, swiggyBody, now),
        'sender is on your ignore list',
      );
      expect(smsRepo.rows, isEmpty);
    });

    test('transfer to one of my accounts is a self transfer', () async {
      ownRepo.last4.add('5678');
      final saved = await process('AX-HDFCBK-S', ownTransfer, now);
      expect(saved!.isSelfTransfer, isTrue);
    });

    test('same transfer without My accounts is normal spending', () async {
      final saved = await process('AX-HDFCBK-S', ownTransfer, now);
      expect(saved!.isSelfTransfer, isFalse);
    });

    test('Bank + Receipt, same amount within 30 minutes → paired', () async {
      final receipt = await process('AD-VAAHAN-S', vaahanReceipt, now);
      final bank = await process(
        'JD-SBIUPI-S',
        vaahanBank,
        now.add(const Duration(minutes: 25)),
      );
      expect(bank!.duplicateOf, receipt!.id);
      expect(smsRepo.rows.first.duplicateOf, bank.id); // linked both ways
      final cards = DetectedSmsProvider.groupPairs(await smsRepo.getPending());
      expect(cards, hasLength(1));
      expect(cards.single.map((s) => s.kind), ['bank', 'receipt']);
    });

    test('31 minutes apart → two separate cards', () async {
      await process('AD-VAAHAN-S', vaahanReceipt, now);
      final bank = await process(
        'JD-SBIUPI-S',
        vaahanBank,
        now.add(const Duration(minutes: 31)),
      );
      expect(bank!.duplicateOf, isNull);
      expect(
        DetectedSmsProvider.groupPairs(await smsRepo.getPending()),
        hasLength(2),
      );
    });
  });

  group('re-check old pending cards', () {
    DetectedSms oldRow(int id, String sender, String body, String type) =>
        DetectedSms(
          id: id,
          sender: sender,
          body: body,
          amountPaise: 100,
          type: type,
          merchant: 'Old',
          receivedAt: now.add(Duration(minutes: id)),
        );

    test('wrong cards are fixed, rejected ones are deleted', () async {
      smsRepo.rows.addAll([
        // Old parser kept this; v2 drops "reward points".
        oldRow(
          1,
          'AX-HDFCBK-S',
          'You have earned 150 reward points on your purchase of Rs 1,500 '
              'at Croma. Redeem now.',
          'income',
        ),
        // Old parser called this income.
        oldRow(2, 'AD-VAAHAN-S', vaahanReceipt, 'income'),
      ]);
      final report = await SmsRecheck(
        smsRepo: smsRepo,
        ignoredRepo: ignoredRepo,
        service: service,
      ).run();

      expect(report.removedIds, [1]);
      expect(report.updated, 1);
      final fixed = smsRepo.rows.single;
      expect(fixed.id, 2);
      expect(fixed.type, 'expense');
      expect(fixed.kind, 'receipt');
      expect(fixed.amountPaise, 12000);
      expect(fixed.merchant, 'Vaahan');
      expect(fixed.status, 'pending');
    });
  });

  group('notification Save / Ignore buttons', () {
    late FakeBudgetAlerts alerts;
    late SmsActionService actions;

    setUp(() {
      alerts = FakeBudgetAlerts();
      actions = SmsActionService(
        smsRepo: smsRepo,
        transactionRepo: txnRepo,
        categoryRepo: FakeCategoryRepo(),
        budgetAlerts: alerts,
      );
    });

    test('Save adds the transaction and marks the SMS saved', () async {
      final sms = await process(swiggySender, swiggyBody, now);
      expect(
        await actions.handle(SmsActionService.saveAction, sms!.id!),
        isTrue,
      );
      expect(txnRepo.inserted.single.amountPaise, 45000);
      expect(txnRepo.inserted.single.categoryId, 1);
      expect(txnRepo.inserted.single.source, 'sms');
      expect(smsRepo.rows.single.status, 'saved');
      expect(alerts.checked, hasLength(1)); // budget alert still checked
    });

    test('Ignore marks it ignored; a second tap does nothing', () async {
      final sms = await process(swiggySender, swiggyBody, now);
      expect(
        await actions.handle(SmsActionService.ignoreAction, sms!.id!),
        isTrue,
      );
      expect(smsRepo.rows.single.status, 'ignored');
      expect(
        await actions.handle(SmsActionService.saveAction, sms.id!),
        isFalse,
      );
      expect(txnRepo.inserted, isEmpty);
    });

    test('a saved self transfer keeps its flag', () async {
      ownRepo.last4.add('5678');
      final sms = await process('AX-HDFCBK-S', ownTransfer, now);
      await actions.handle(SmsActionService.saveAction, sms!.id!);
      expect(txnRepo.inserted.single.isSelfTransfer, isTrue);
    });

    test('paired notification text', () {
      final sms = DetectedSms(
        sender: 'JD-SBIUPI-S',
        body: 'x',
        amountPaise: 12000,
        type: 'expense',
        merchant: 'Parivahan Pay',
        receivedAt: now,
      );
      expect(
        NotificationService.pairedText(sms),
        '₹120 to Parivahan Pay — matches another SMS. Tap to merge',
      );
    });
  });
}
