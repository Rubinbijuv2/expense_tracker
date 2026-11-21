import 'dart:io';

import 'package:expense_tracker/models/merchant_rule.dart';
import 'package:expense_tracker/screens/settings/sample_sms_data.dart';
import 'package:expense_tracker/services/category_guesser.dart';
import 'package:expense_tracker/services/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// One usable line from test/fixtures/sample_sms.txt.
class _Case {
  final int lineNo;
  final String sender;
  final String body;
  final String expected; // 'IGNORE' or 'amount ; type ; merchant ; mode'
  _Case(this.lineNo, this.sender, this.body, this.expected);
}

List<_Case> _loadCases([String file = 'test/fixtures/sample_sms.txt']) {
  // `flutter test` runs from the project folder, so this path is relative to it.
  final lines = File(file).readAsLinesSync();
  final cases = <_Case>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|').map((p) => p.trim()).toList();
    if (parts.length < 3) fail('Line ${i + 1} needs SENDER | BODY | EXPECTED');
    final body = parts.sublist(1, parts.length - 1).join('|');
    cases.add(_Case(i + 1, parts.first, body, parts.last));
  }
  return cases;
}

void main() {
  group('sample_sms.txt', () {
    final cases = _loadCases();

    test('fixture file has both kinds of cases', () {
      expect(cases.where((c) => c.expected == 'IGNORE'), isNotEmpty);
      expect(cases.where((c) => c.expected != 'IGNORE'), isNotEmpty);
    });

    // The Test SMS screen has its own copy of these messages
    // (lib/screens/settings/sample_sms_data.dart). Keep them identical.
    test('Test SMS screen samples match the fixture file', () {
      expect(
        sampleSmsList.map((s) => '${s.sender} | ${s.body}').toList(),
        cases.map((c) => '${c.sender} | ${c.body}').toList(),
      );
    });

    for (final c in cases) {
      test('line ${c.lineNo}: ${c.sender} → ${c.expected}', () {
        final result = SmsParser.parse(c.sender, c.body);

        if (c.expected == 'IGNORE') {
          expect(result, isNull, reason: 'should be ignored: ${c.body}');
          return;
        }

        final want = c.expected.split(';').map((p) => p.trim()).toList();
        expect(want.length, 4, reason: 'expected needs 4 parts');
        expect(result, isNotNull, reason: 'should be parsed: ${c.body}');
        expect(result!.amountPaise, (double.parse(want[0]) * 100).round());
        expect(result.type, want[1]);
        expect(result.merchant, want[2]);
        expect(result.paymentMode, want[3]);
      });
    }
  });

  group('sample_sms_v2.txt', () {
    final cases = _loadCases('test/fixtures/sample_sms_v2.txt');

    test('fixture file has both kinds of cases', () {
      expect(cases.where((c) => c.expected == 'IGNORE'), isNotEmpty);
      expect(cases.where((c) => c.expected != 'IGNORE'), isNotEmpty);
    });

    for (final c in cases) {
      test('line ${c.lineNo}: ${c.sender} → ${c.expected}', () {
        final result = SmsParser.parse(c.sender, c.body);

        if (c.expected == 'IGNORE') {
          expect(result, isNull, reason: 'should be ignored: ${c.body}');
          return;
        }

        final want = c.expected.split(';').map((p) => p.trim()).toList();
        expect(want.length, 6, reason: 'expected needs 6 parts');
        expect(result, isNotNull, reason: 'should be parsed: ${c.body}');
        expect(result!.amountPaise, (double.parse(want[0]) * 100).round());
        expect(result.type, want[1], reason: 'type');
        expect(result.merchant, want[2], reason: 'merchant');
        expect(
          result.paymentMode,
          want[3] == 'none' ? null : want[3],
          reason: 'mode',
        );
        expect(result.kind, want[4], reason: 'kind');
        expect(
          CategoryGuesser.guessSms(result, []).categoryName,
          want[5],
          reason: 'category',
        );
      });
    }
  });

  group('SmsParser details', () {
    test('rupeesToPaise handles commas and short decimals', () {
      expect(SmsParser.rupeesToPaise('1,299.00'), 129900);
      expect(SmsParser.rupeesToPaise('120.0'), 12000);
      expect(SmsParser.rupeesToPaise('199'), 19900);
      expect(SmsParser.rupeesToPaise('0.05'), 5);
    });

    test('reads account last digits', () {
      final r = SmsParser.parse(
        'AX-HDFCBK',
        'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@axisbank',
      );
      expect(r!.accountLast4, '1234');
    });

    test('accepts -S / -T sender suffix', () {
      expect(
        SmsParser.parse('AX-HDFCBK-S', 'Rs 10 debited to VPA a@b'),
        isNotNull,
      );
    });

    test('UPI ID with dots becomes words', () {
      final r = SmsParser.parse(
        'VM-ICICIB',
        'Rs.50 received from rahul.kumar@okaxis on 01-11-26',
      );
      expect(r!.merchant, 'Rahul Kumar');
    });

    test('-P (promotional) sender is always ignored', () {
      final r = SmsParser.parseWithReason(
        'AX-HDFCBK-P',
        'Rs 10 debited from A/c XX1234',
      );
      expect(r.sms, isNull);
      expect(r.ignoredReason, contains('promotional'));
    });

    test('-G (government) sender and 9-letter names are accepted', () {
      expect(
        SmsParser.parse('VM-ITDCPC-G', 'Payment received for Challan Rs 10'),
        isNotNull,
      );
      expect(
        SmsParser.parse('VM-ABCDEFGHI', 'Rs 10 debited from A/c XX1234'),
        isNotNull,
      );
    });

    test('ignored_senders list is respected (any letter case)', () {
      const body = 'Rs 10 debited from A/c XX1234 to VPA a@b';
      expect(SmsParser.parse('AX-HDFCBK', body), isNotNull);
      final r = SmsParser.parseWithReason(
        'ax-hdfcbk',
        body,
        ignoredSenders: {'AX-HDFCBK'},
      );
      expect(r.sms, isNull);
      expect(r.ignoredReason, contains('ignore list'));
    });

    test('cashback promo is dropped but real cashback is kept', () {
      expect(
        SmsParser.parse(
          'AX-AXISBK-S',
          'Get cashback on Rs 500 spent. Apply now',
        ),
        isNull,
      );
      expect(
        SmsParser.parse(
          'AX-AXISBK-S',
          'Cashback of Rs 25 credited to your A/c XX4321',
        )?.type,
        'income',
      );
    });

    test('debited with "Your A/c" stays an expense', () {
      final r = SmsParser.parse(
        'JD-ICICIB',
        'Your A/c XX901 debited for Rs 100.00; ZOMATO credited. UPI 6324',
      );
      expect(r!.type, 'expense');
      expect(r.merchant, 'Zomato');
    });
  });

  group('CategoryGuesser (rule 10)', () {
    test('keyword map', () {
      expect(CategoryGuesser.guess('Swiggy', []).categoryName, 'Food');
      expect(CategoryGuesser.guess('Uber India', []).categoryName, 'Travel');
      expect(CategoryGuesser.guess('Amazon Pay', []).categoryName, 'Shopping');
      expect(CategoryGuesser.guess('Jio Prepaid', []).categoryName, 'Bills');
      expect(
        CategoryGuesser.guess('Netflix', []).categoryName,
        'Entertainment',
      );
      expect(
        CategoryGuesser.guess('Apollo Pharmacy', []).categoryName,
        'Health',
      );
    });

    test('short keywords need a whole word', () {
      expect(CategoryGuesser.guess('Ravi', []).categoryName, 'Others');
      expect(
        CategoryGuesser.guess('Motorola Store', []).categoryName,
        'Others',
      );
      expect(CategoryGuesser.guess('Vi Postpaid', []).categoryName, 'Bills');
    });

    test('learned merchant rule beats keyword map', () {
      final rules = [const MerchantRule(keyword: 'amazon pay', categoryId: 4)];
      final g = CategoryGuesser.guess('Amazon Pay', rules);
      expect(g.isFromRule, isTrue);
      expect(g.categoryId, 4);
    });

    test('longest matching rule wins', () {
      final rules = [
        const MerchantRule(keyword: 'amazon', categoryId: 3),
        const MerchantRule(keyword: 'amazon pay', categoryId: 4),
      ];
      expect(CategoryGuesser.guess('Amazon Pay', rules).categoryId, 4);
    });

    test('new keywords: Vehicle and Tax & Govt', () {
      expect(CategoryGuesser.guess('Vaahan', []).categoryName, 'Vehicle');
      expect(
        CategoryGuesser.guess('Hp Petrol Pump', []).categoryName,
        'Vehicle',
      );
      expect(
        CategoryGuesser.guess('Gst Payment', []).categoryName,
        'Tax & Govt',
      );
      expect(CategoryGuesser.guess('Harithamithram', []).categoryName, 'Bills');
      expect(CategoryGuesser.guess('Itdcpc', []).categoryName, 'Others');
    });

    ParsedSms income(String body, {String merchant = 'Abc'}) => ParsedSms(
      sender: 'AX-HDFCBK',
      body: body,
      amountPaise: 100,
      type: 'income',
      merchant: merchant,
      kind: 'bank',
    );

    test('income: Salary only when the SMS says salary or SAL', () {
      expect(
        CategoryGuesser.guessSms(
          income('Rs 1 credited. SAL NOV'),
          [],
        ).categoryName,
        'Salary',
      );
      expect(
        CategoryGuesser.guessSms(
          income('Rs 1 credited, salary'),
          [],
        ).categoryName,
        'Salary',
      );
      expect(
        CategoryGuesser.guessSms(
          income('Rs 1 credited. Big sale'),
          [],
        ).categoryName,
        'Money received',
      );
    });

    test('income: refund and cashback beat merchant rules', () {
      final rules = [const MerchantRule(keyword: 'flipkart', categoryId: 3)];
      final r = income('Refund of Rs 1 credited', merchant: 'Flipkart');
      expect(CategoryGuesser.guessSms(r, rules).categoryName, 'Refund');
      expect(
        CategoryGuesser.guessSms(
          income('Cashback of Rs 1 credited'),
          rules,
        ).categoryName,
        'Cashback',
      );
    });

    test('unknown merchant → Others', () {
      expect(CategoryGuesser.guess('Unknown', []).categoryName, 'Others');
    });
  });
}
