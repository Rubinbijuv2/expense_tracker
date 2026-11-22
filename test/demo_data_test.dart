import 'package:expense_tracker/data/default_categories.dart';
import 'package:expense_tracker/data/detected_sms_repo.dart';
import 'package:expense_tracker/data/own_account_repo.dart';
import 'package:expense_tracker/data/recurring_installment_repo.dart';
import 'package:expense_tracker/data/recurring_payment_repo.dart';
import 'package:expense_tracker/data/transaction_repo.dart';
import 'package:expense_tracker/models/recurring_installment.dart';
import 'package:expense_tracker/services/demo_data_generator.dart';
import 'package:expense_tracker/services/demo_data_service.dart';
import 'package:expense_tracker/services/demo_repeat_payments.dart';
import 'package:expense_tracker/services/notification_parser.dart';
import 'package:expense_tracker/services/recurring_match.dart';
import 'package:expense_tracker/services/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed "now" so the test gives the same answer every day.
  final now = DateTime(2026, 11, 21, 18, 30);
  final demo = DemoDataGenerator.generate(now);

  group('DemoDataGenerator.generate', () {
    test('covers 2 full months before this month plus this month so far', () {
      expect(demo.first.dateTime.isBefore(DateTime(2026, 9, 3)), isTrue);
      expect(demo.any((d) => d.dateTime.month == 10), isTrue);
      expect(demo.any((d) => d.dateTime.month == 11), isTrue);
      expect(
        demo.every((d) => !d.dateTime.isAfter(now)),
        isTrue,
        reason: 'no transactions in the future',
      );
      expect(
        demo.every((d) => !d.dateTime.isBefore(DateTime(2026, 9))),
        isTrue,
      );
    });

    test('has a realistic amount of data', () {
      expect(demo.length, inInclusiveRange(80, 200));
      expect(demo.every((d) => d.amountPaise > 0), isTrue);
    });

    test('salary and rent appear once in every month', () {
      for (final month in [9, 10, 11]) {
        final inMonth = demo.where((d) => d.dateTime.month == month);
        expect(
          inMonth.where((d) => d.merchant == 'ABC Technologies'),
          hasLength(1),
        );
        expect(inMonth.where((d) => d.category == 'Rent'), hasLength(1));
      }
    });

    test('uses only default category names, with the right type', () {
      final types = {for (final c in defaultCategories) c.name: c.type};
      for (final d in demo) {
        expect(types[d.category], d.type, reason: '${d.category} ${d.type}');
      }
    });

    test('is sorted oldest first and the same every time', () {
      for (var i = 1; i < demo.length; i++) {
        expect(demo[i].dateTime.isBefore(demo[i - 1].dateTime), isFalse);
      }
      final again = DemoDataGenerator.generate(now);
      expect(
        again.map((d) => d.amountPaise).toList(),
        demo.map((d) => d.amountPaise).toList(),
      );
    });

    test('works on the 1st of January (months cross the year)', () {
      final jan = DemoDataGenerator.generate(DateTime(2027, 1, 1, 12));
      expect(jan.first.dateTime.year, 2026);
      expect(jan.first.dateTime.month, 11);
      expect(jan.any((d) => d.dateTime.year == 2027), isTrue); // salary 1 Jan
    });
  });

  test('demo SMS are read by the real parser', () {
    final parsed = [
      for (final (sender, body, _) in DemoDataService.demoSms(now))
        SmsParser.parseWithReason(sender, body).sms,
    ];
    expect(parsed[0]?.amountPaise, 38600);
    expect(parsed[0]?.merchant, 'Zomato');
    expect(parsed[1]?.amountPaise, 21400);
    expect(parsed[1]?.type, 'expense');
  });

  group('DemoRepeatPayments.build', () {
    final repeats = DemoRepeatPayments.build(now);
    DemoRepeat ofType(String t) =>
        repeats.singleWhere((r) => r.payment.type == t);

    test('has exactly one EMI, one chitti and one fee', () {
      expect(repeats.map((r) => r.payment.type).toList()..sort(), [
        'chitti',
        'emi',
        'fee',
      ]);
      final names = {for (final c in defaultCategories) c.name};
      for (final r in repeats) {
        expect(names, contains(r.categoryName));
      }
    });

    test('past months are paid, the next one is pending', () {
      for (final r in repeats) {
        expect(r.installments.last.isPaid, isFalse, reason: r.payment.name);
        expect(
          r.installments.last.dueDate.isBefore(DateTime(2026, 11, 21)),
          isFalse,
        );
        for (final i in r.installments) {
          if (i.isPaid) expect(i.dueDate.isBefore(now), isTrue);
        }
      }
      // 21 Nov: EMI on the 5th, Feb–Nov paid → "10 of 24".
      expect(ofType('emi').installments.where((i) => i.isPaid), hasLength(10));
    });

    test('the chitti is 2 days overdue and the fee is due in 3 days', () {
      final chitti = ofType('chitti').installments;
      final late = chitti.where((i) => !i.isPaid).first;
      expect(late.dueDate, DateTime(2026, 11, 19));
      expect(ofType('fee').installments.last.dueDate, DateTime(2026, 11, 24));
      // The chitti amount changes from month to month.
      final paid = chitti.where((i) => i.isPaid).map((i) => i.paidPaise);
      expect(paid.toSet().length, greaterThan(1));
    });

    test('works early in the month and across the year', () {
      for (final day in [DateTime(2027, 1, 1, 9), DateTime(2027, 1, 2, 9)]) {
        final list = DemoRepeatPayments.build(day);
        expect(list, hasLength(3));
        for (final r in list) {
          expect(r.installments.last.isPaid, isFalse);
        }
      }
    });

    test('the demo chitti SMS matches the overdue chitti', () {
      final chitti = ofType('chitti');
      final late = chitti.installments.firstWhere((i) => !i.isPaid);
      final (sender, body, at) = DemoDataService.demoSms(now)[2];
      final parsed = SmsParser.parseWithReason(sender, body).sms!;
      expect(
        RecurringMatch.matches(
          p: chitti.payment,
          inst: RecurringInstallment(recurringId: 0, dueDate: late.dueDate),
          amountPaise: parsed.amountPaise,
          date: at,
          text: body,
        ),
        isTrue,
      );
    });
  });

  test('every demo SMS and notification is read by the real parsers', () {
    for (final (sender, body, _) in DemoDataService.demoSms(now)) {
      final r = SmsParser.parseWithReason(sender, body);
      expect(r.sms, isNotNull, reason: '$sender: ${r.ignoredReason}');
    }
    for (final n in DemoDataService.demoNotifications(now)) {
      final r = NotificationParser.parseWithReason(
        n.packageName,
        n.title,
        n.text,
      );
      expect(r.sms, isNotNull, reason: '${n.title}: ${r.ignoredReason}');
    }
  });

  test('loading demo data fills every table (real database)', () async {
    final count = await DemoDataService().replaceWithDemoData();
    expect(await TransactionRepo().getAll(), hasLength(count));

    final repeats = await RecurringPaymentRepo().getAll();
    expect(repeats.map((p) => p.type).toSet(), {'emi', 'chitti', 'fee'});
    final insts = await RecurringInstallmentRepo().getAll();
    final linked = insts.where((i) => i.isPaid && i.transactionId != null);
    expect(linked, isNotEmpty, reason: 'paid months have an expense');

    expect(await OwnAccountRepo().getAllLast4(), {'9012'});

    final pending = await DetectedSmsRepo().getPending();
    expect(pending, hasLength(8)); // 6 SMS + 2 app notifications
    expect(pending.where((s) => s.isNotification), hasLength(2));
    expect(pending.where((s) => s.isSelfTransfer), hasLength(1));
    expect(
      pending.where((s) => s.kind == 'receipt' && !s.isNotification),
      hasLength(1),
    );
    final gpay = pending.singleWhere(
      (s) => s.amountPaise == 64000 && s.isNotification,
    );
    expect(gpay.duplicateOf, isNotNull, reason: 'paired with the bank SMS');
  });
}
