import 'package:expense_tracker/models/detected_sms.dart';
import 'package:expense_tracker/providers/detected_sms_provider.dart';
import 'package:expense_tracker/services/payment_notification_service.dart';
import 'package:expense_tracker/services/sms_recheck.dart';
import 'package:expense_tracker/services/sms_service.dart';
import 'package:flutter_test/flutter_test.dart';

// The fake repos (lists instead of SQLite) from the SMS pipeline tests.
import 'sms_service_test.dart'
    show
        FakeCategoryRepo,
        FakeIgnoredRepo,
        FakeOwnRepo,
        FakeRuleRepo,
        FakeSmsRepo,
        FakeTxnRepo,
        swiggyBody,
        swiggySender;

/// Adds the notification duplicate check (section 7.5) to the fake repo.
class FakeAppSmsRepo extends FakeSmsRepo {
  @override
  Future<bool> existsRecentFromApp(
    String app,
    int amountPaise,
    String body,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async => rows.any(
    (r) =>
        r.isNotification &&
        r.sender == app &&
        r.amountPaise == amountPaise &&
        r.body == body &&
        r.receivedAt.difference(at).abs() <= window,
  );

  /// Like the real query: notifications are not "similar pending SMS".
  @override
  Future<bool> existsSimilarPending(
    int amountPaise,
    String merchant,
    DateTime at, {
    Duration window = const Duration(minutes: 2),
  }) async => rows.any(
    (r) =>
        r.isPending &&
        !r.isNotification &&
        r.amountPaise == amountPaise &&
        r.merchant?.toLowerCase() == merchant.toLowerCase() &&
        r.receivedAt.difference(at).abs() <= window,
  );
}

const gpay = 'com.google.android.apps.nbu.paisa.user';

void main() {
  late FakeAppSmsRepo smsRepo;
  late FakeTxnRepo txnRepo;
  late FakeIgnoredRepo ignoredRepo;
  late SmsService smsService;
  late PaymentNotificationService service;
  final now = DateTime(2026, 11, 20, 13, 5);

  setUp(() {
    smsRepo = FakeAppSmsRepo();
    txnRepo = FakeTxnRepo();
    ignoredRepo = FakeIgnoredRepo();
    smsService = SmsService(
      smsRepo: smsRepo,
      transactionRepo: txnRepo,
      ruleRepo: FakeRuleRepo(),
      categoryRepo: FakeCategoryRepo(),
      ignoredRepo: ignoredRepo,
      ownRepo: FakeOwnRepo(),
    );
    service = PaymentNotificationService(
      smsService: smsService,
      smsRepo: smsRepo,
      transactionRepo: txnRepo,
      ignoredRepo: ignoredRepo,
    );
  });

  AppNotification n(
    String title,
    String text,
    DateTime at, [
    String pkg = gpay,
  ]) =>
      AppNotification(packageName: pkg, title: title, text: text, postedAt: at);

  test('payment notification becomes a pending App card', () async {
    final r = await service.process(
      n('Payment successful', '₹450 paid to Swiggy', now),
    );
    final saved = r.saved;
    expect(saved, isNotNull, reason: r.ignoredReason);
    expect(saved!.source, 'notification');
    expect(saved.sourceApp, 'Google Pay');
    expect(saved.kindLabel, 'App · Google Pay');
    expect(saved.amountPaise, 45000);
    expect(saved.type, 'expense');
    expect(saved.paymentMode, 'UPI');
    expect(saved.guessedCategoryId, 1); // Food (same guesser as SMS)
    expect(saved.status, 'pending');
    expect(smsRepo.rows, hasLength(1));
  });

  test('income notification gets Money received', () async {
    final saved = (await service.process(
      n('Rahul Menon paid you ₹500', 'Tap to see details', now),
    )).saved;
    expect(saved!.type, 'income');
    expect(saved.guessedCategoryId, 16); // Money received
  });

  test('other apps are never stored', () async {
    final r = await service.process(
      n('Rahul', 'Sent you ₹500 for the movie', now, 'com.whatsapp'),
    );
    expect(r.ignoredReason, 'not an allow-listed payment app');
    expect(smsRepo.rows, isEmpty);
  });

  test('same notification again within 2 minutes is skipped', () async {
    final first = n('Payment successful', '₹450 paid to Swiggy', now);
    expect((await service.process(first)).isSaved, isTrue);
    final again = n(
      'Payment successful',
      '₹450 paid to Swiggy',
      now.add(const Duration(seconds: 50)),
    );
    expect(
      (await service.process(again)).ignoredReason,
      'duplicate (same notification within 2 minutes)',
    );
    // A real second payment later the same day is kept.
    final later = n(
      'Payment successful',
      '₹450 paid to Swiggy',
      now.add(const Duration(hours: 3)),
    );
    expect((await service.process(later)).isSaved, isTrue);
    expect(smsRepo.rows, hasLength(2));
  });

  test(
    'bank SMS then notification within 30 minutes → one merge card',
    () async {
      final sms = (await smsService.processMessage(
        swiggySender,
        swiggyBody,
        now,
      )).saved!;
      final app = (await service.process(
        n(
          'Payment successful',
          '₹450 paid to Swiggy',
          now.add(const Duration(minutes: 1)),
        ),
      )).saved!;

      expect(app.duplicateOf, sms.id);
      expect(
        smsRepo.rows.firstWhere((r) => r.id == sms.id).duplicateOf,
        app.id,
      );

      final cards = DetectedSmsProvider.groupPairs(await smsRepo.getPending());
      expect(cards, hasLength(1));
      expect(cards.first.first.id, sms.id); // bank SMS first (account number)
      expect(cards.first.last.isNotification, isTrue); // merchant from the app
    },
  );

  test('notification then bank SMS also pairs', () async {
    final app = (await service.process(
      n('Paid ₹450 to Swiggy', 'Payment successful', now),
    )).saved!;
    final sms = (await smsService.processMessage(
      swiggySender,
      swiggyBody,
      now.add(const Duration(minutes: 10)),
    )).saved!;
    expect(sms.duplicateOf, app.id);
  });

  test('income notification does not pair with an expense SMS', () async {
    await smsService.processMessage(swiggySender, swiggyBody, now);
    final app = (await service.process(
      n('Rahul paid you ₹450', '', now.add(const Duration(minutes: 1))),
    )).saved!;
    expect(app.duplicateOf, isNull);
  });

  test('Re-check pending SMS leaves notification cards alone', () async {
    final sms = (await smsService.processMessage(
      swiggySender,
      swiggyBody,
      now,
    )).saved!;
    final app = (await service.process(
      n('Payment successful', '₹450 paid to Swiggy', now),
    )).saved!;

    final report = await SmsRecheck(
      smsRepo: smsRepo,
      ignoredRepo: ignoredRepo,
      service: smsService,
    ).run();

    expect(report.removed, 0);
    final rows = {for (final r in smsRepo.rows) r.id: r};
    expect(rows[app.id], isA<DetectedSms>());
    expect(rows[app.id]!.duplicateOf, sms.id);
    expect(rows[sms.id]!.duplicateOf, app.id); // pair kept
  });
}
