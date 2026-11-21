import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _txn(DateTime when, int paise, String type) =>
    TransactionModel(
      amountPaise: paise,
      type: type,
      categoryId: 1,
      paymentMode: 'UPI',
      dateTime: when,
    );

void main() {
  group('validateAmount', () {
    test('accepts valid amounts', () {
      expect(validateAmount('250'), isNull);
      expect(validateAmount('99.50'), isNull);
      expect(validateAmount('0.01'), isNull);
      expect(validateAmount('1,234.5'), isNull);
    });

    test('rejects empty input', () {
      expect(validateAmount(null), 'Enter an amount');
      expect(validateAmount(''), 'Enter an amount');
      expect(validateAmount('   '), 'Enter an amount');
    });

    test('rejects zero', () {
      expect(validateAmount('0'), 'Amount must be more than ₹0');
      expect(validateAmount('0.00'), 'Amount must be more than ₹0');
    });

    test('rejects badly formed numbers', () {
      for (final bad in ['.', '1.2.3', '12.345', 'abc', '-5']) {
        expect(
          validateAmount(bad),
          startsWith('Enter a valid amount'),
          reason: bad,
        );
      }
    });
  });

  group('validateCategory', () {
    test('requires a category', () {
      expect(validateCategory(null), 'Pick a category');
      expect(validateCategory(3), isNull);
    });
  });

  group('TransactionProvider.groupByDay', () {
    test('groups by calendar day with separate expense and income totals', () {
      final txns = [
        _txn(DateTime(2026, 11, 20, 21, 0), 15000, 'expense'),
        _txn(DateTime(2026, 11, 20, 9, 30), 50000, 'income'),
        _txn(DateTime(2026, 11, 20, 0, 5), 2550, 'expense'),
        _txn(DateTime(2026, 11, 18, 23, 59), 10000, 'expense'),
      ];
      final groups = TransactionProvider.groupByDay(txns);

      expect(groups.length, 2);
      expect(groups[0].day, DateTime(2026, 11, 20));
      expect(groups[0].items.length, 3);
      expect(groups[0].expensePaise, 17550);
      expect(groups[0].incomePaise, 50000);
      expect(groups[1].day, DateTime(2026, 11, 18));
      expect(groups[1].expensePaise, 10000);
      expect(groups[1].incomePaise, 0);
    });

    test('returns an empty list for no transactions', () {
      expect(TransactionProvider.groupByDay([]), isEmpty);
    });
  });
}
