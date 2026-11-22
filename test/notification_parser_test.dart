import 'dart:io';

import 'package:expense_tracker/screens/settings/sample_notification_data.dart';
import 'package:expense_tracker/services/notification_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// One usable line from test/fixtures/sample_notifications.txt:
/// PACKAGE | TITLE | TEXT | EXPECTED (amount ; type ; merchant ; mode) or
/// IGNORE (reason).
class _Case {
  final String package, title, text, expected;
  _Case(this.package, this.title, this.text, this.expected);

  bool get isIgnore => expected.startsWith('IGNORE');
  String get name => '$package | $title | $text';
}

List<_Case> _loadCases() {
  final lines = File('test/fixtures/sample_notifications.txt')
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'));
  return [
    for (final l in lines)
      () {
        final p = l.split(' | ');
        return _Case(p[0].trim(), p[1].trim(), p[2].trim(), p[3].trim());
      }(),
  ];
}

void main() {
  final cases = _loadCases();

  group('sample_notifications.txt', () {
    test('fixture has cases', () => expect(cases, hasLength(12)));

    for (final c in cases) {
      test(c.name, () {
        final r = NotificationParser.parseWithReason(
          c.package,
          c.title,
          c.text,
        );
        if (c.isIgnore) {
          expect(r.sms, isNull, reason: 'should be ignored');
          return;
        }
        final want = c.expected.split(';').map((s) => s.trim()).toList();
        final sms = r.sms;
        expect(sms, isNotNull, reason: 'ignored: ${r.ignoredReason}');
        final rupees = want[0].split('.');
        expect(
          sms!.amountPaise,
          int.parse(rupees[0]) * 100 + int.parse(rupees[1]),
        );
        expect(sms.type, want[1]);
        expect(sms.merchant, want[2]);
        expect(sms.paymentMode, want[3]);
        expect(sms.kind, 'receipt'); // pairs with a bank SMS
        expect(sms.sender, NotificationParser.appName(c.package));
      });
    }

    // The developer screen has its own copy of the fixture
    // (lib/screens/settings/sample_notification_data.dart). Keep them identical.
    test('Test notification samples match the fixture file', () {
      expect(
        sampleNotificationList
            .map((s) => '${s.packageName} | ${s.title} | ${s.text}')
            .toList(),
        cases.map((c) => c.name).toList(),
      );
    });
  });

  group('ignore reasons', () {
    const gpay = 'com.google.android.apps.nbu.paisa.user';
    String? reason(String title, String text, [String pkg = gpay]) =>
        NotificationParser.parseWithReason(pkg, title, text).ignoredReason;

    test('apps outside the allow-list are always ignored', () {
      expect(
        reason('Paid ₹450 to Swiggy', 'Payment successful', 'com.whatsapp'),
        'not an allow-listed payment app',
      );
      expect(
        reason('₹450 paid to Swiggy', '', 'com.example.fakepay'),
        'not an allow-listed payment app',
      );
    });

    test('requests, failures, pending, reminders, offers, rewards', () {
      expect(reason('Rahul requested ₹200', 'Tap to pay'), 'payment request');
      expect(reason('Payment failed', '₹300 to Zomato'), 'failed');
      expect(reason('Payment declined', '₹300 to Zomato'), 'failed');
      expect(reason('Payment pending', '₹300 paid to Zomato'), 'pending');
      expect(reason('Reminder', 'Pay ₹499 to Airtel'), 'bill reminder');
      expect(reason('Bill due on 5 Dec', '₹1,200 for BESCOM'), 'bill reminder');
      expect(reason('Get ₹100 cashback', 'On bill payment'), 'offer');
      expect(reason('You won ₹10 cashback', 'Paid ₹50 to Ola'), 'reward');
      expect(
        reason('Hello', 'Your account is ready'),
        'not a payment notification',
      );
    });

    test('ignored app ("Always ignore") is dropped', () {
      final r = NotificationParser.parseWithReason(
        gpay,
        'Paid ₹450 to Swiggy',
        '',
        ignoredApps: {'GOOGLE PAY'},
      );
      expect(r.ignoredReason, 'app is on your ignore list');
    });
  });

  group('patterns', () {
    const phonepe = 'com.phonepe.app';
    test('all wordings from PLAN.md 7.4', () {
      final cases = {
        '₹450 paid to Swiggy': ('expense', 'Swiggy'),
        'Paid ₹450 to Swiggy': ('expense', 'Swiggy'),
        'You paid ₹450 to Swiggy': ('expense', 'Swiggy'),
        'Payment of ₹450 to Swiggy successful': ('expense', 'Swiggy'),
        'Rahul paid you ₹500': ('income', 'Rahul'),
        'Received ₹500 from Rahul': ('income', 'Rahul'),
        '₹500 received from Rahul': ('income', 'Rahul'),
      };
      cases.forEach((title, want) {
        final sms = NotificationParser.parse(phonepe, title, '');
        expect(sms, isNotNull, reason: title);
        expect(sms!.type, want.$1, reason: title);
        expect(sms.merchant, want.$2, reason: title);
        expect(sms.amountPaise, title.contains('450') ? 45000 : 50000);
      });
    });

    test('paise, Rs and big text', () {
      final sms = NotificationParser.parse(
        phonepe,
        'Payment successful',
        '₹1,299.5 paid…',
        bigText: '₹1,299.5 paid… Rs 1,299.50 paid to AMAZON PAY. UPI Ref 1',
      );
      expect(sms, isNotNull);
      expect(sms!.amountPaise, 129950);
      expect(sms.merchant, 'Amazon Pay');
      expect(sms.body, contains('UPI Ref 1')); // big text kept
    });

    test('UPI id with dots becomes a name', () {
      final sms = NotificationParser.parse(
        phonepe,
        'Sent ₹80 to rahul.k@okaxis',
        '',
      );
      expect(sms!.merchant, 'Rahul K');
    });
  });
}
