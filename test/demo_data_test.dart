import 'package:expense_tracker/data/default_categories.dart';
import 'package:expense_tracker/services/demo_data_generator.dart';
import 'package:expense_tracker/services/demo_data_service.dart';
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
}
