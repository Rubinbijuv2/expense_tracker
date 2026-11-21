import 'package:expense_tracker/data/default_categories.dart';
import 'package:expense_tracker/data/transaction_repo.dart';
import 'package:expense_tracker/utils/category_icons.dart';
import 'package:expense_tracker/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPaise', () {
    test('formats basic amounts', () {
      expect(formatPaise(123450), '₹1,234.50');
      expect(formatPaise(0), '₹0.00');
      expect(formatPaise(5), '₹0.05');
      expect(formatPaise(99), '₹0.99');
      expect(formatPaise(100), '₹1.00');
      expect(formatPaise(99999), '₹999.99');
    });

    test('uses Indian grouping (lakh, crore)', () {
      expect(formatPaise(10000000), '₹1,00,000.00');
      expect(formatPaise(12345678), '₹1,23,456.78');
      expect(formatPaise(1234567890), '₹1,23,45,678.90');
    });

    test('shows negative amounts with a leading minus', () {
      expect(formatPaise(-50000), '-₹500.00');
      expect(formatPaise(-123456), '-₹1,234.56');
    });
  });

  group('parseToPaise', () {
    test('parses plain and formatted amounts', () {
      expect(parseToPaise('1234.50'), 123450);
      expect(parseToPaise('1234.5'), 123450);
      expect(parseToPaise('1234'), 123400);
      expect(parseToPaise('0.05'), 5);
      expect(parseToPaise('0'), 0);
      expect(parseToPaise('₹1,234.50'), 123450);
      expect(parseToPaise(' ₹ 1,23,456.78 '), 12345678);
      expect(parseToPaise('Rs. 500'), 50000);
      expect(parseToPaise('rs500'), 50000);
      expect(parseToPaise('INR 2,000'), 200000);
    });

    test('has no floating-point rounding errors', () {
      expect(parseToPaise('0.29'), 29);
      expect(parseToPaise('1.15'), 115);
      expect(parseToPaise('19.99'), 1999);
    });

    test('returns null for invalid input', () {
      for (final bad in [
        null,
        '',
        '   ',
        'abc',
        '12.345',
        '-5',
        '1.2.3',
        '.5',
        '5.',
        '₹',
      ]) {
        expect(parseToPaise(bad), isNull, reason: 'input: $bad');
      }
    });

    test('round-trips with formatPaise', () {
      for (final p in [0, 1, 50, 123450, 12345678, 999999999]) {
        expect(parseToPaise(formatPaise(p)), p);
        expect(parseToPaise(paiseToInput(p)), p);
      }
    });
  });

  test('paiseToInput gives a plain editable number', () {
    expect(paiseToInput(123450), '1234.50');
    expect(paiseToInput(123405), '1234.05');
    expect(paiseToInput(50000), '500');
  });

  test('monthKey gives YYYY-MM', () {
    expect(monthKey(DateTime(2026, 1, 31)), '2026-01');
    expect(monthKey(DateTime(2026, 11, 20, 23, 59)), '2026-11');
  });

  test('monthRange handles December rolling into January', () {
    final (start, end) = TransactionRepo.monthRange(DateTime(2026, 12, 15));
    expect(start, '2026-12-01T00:00:00.000');
    expect(end, '2027-01-01T00:00:00.000');
  });

  test('every default category has a known icon', () {
    expect(defaultCategories.length, 20); // PLAN.md rule 11
    for (final c in defaultCategories) {
      expect(categoryIcons.containsKey(c.icon), isTrue, reason: c.name);
    }
  });
}
