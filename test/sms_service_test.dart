import 'package:expense_tracker/data/category_repo.dart';
import 'package:expense_tracker/data/detected_sms_repo.dart';
import 'package:expense_tracker/data/merchant_rule_repo.dart';
import 'package:expense_tracker/data/transaction_repo.dart';
import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/detected_sms.dart';
import 'package:expense_tracker/models/merchant_rule.dart';
import 'package:expense_tracker/providers/detected_sms_provider.dart';
import 'package:expense_tracker/services/notification_service.dart';
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
  late SmsService service;
  final now = DateTime(2026, 11, 20, 13, 5);

  setUp(() {
    smsRepo = FakeSmsRepo();
    txnRepo = FakeTxnRepo();
    ruleRepo = FakeRuleRepo();
    service = SmsService(
      smsRepo: smsRepo,
      transactionRepo: txnRepo,
      ruleRepo: ruleRepo,
      categoryRepo: FakeCategoryRepo(),
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

    test('income gets an income category (Salary)', () async {
      final saved = await process(
        'VM-ICICIB',
        'Dear Customer, Rs.649.00 received in your account XX901 from '
            'rahul@okhdfcbank on 15-11-26. UPI Ref 632477778888',
        now,
      );
      expect(saved!.type, 'income');
      expect(saved.guessedCategoryId, 9);
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
}
