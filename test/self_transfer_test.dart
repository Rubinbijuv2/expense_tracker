import 'package:expense_tracker/models/report_summary.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/dashboard_provider.dart';
import 'package:expense_tracker/providers/history_provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/services/export_service.dart';
import 'package:expense_tracker/services/self_transfer.dart';
import 'package:expense_tracker/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelfTransfer.detect (PLAN.md rule 13)', () {
    const toOwn =
        'Rs.5,000.00 sent from A/c XX1234 to A/c XX5678 via IMPS on 20-11-26.';

    test('counterparty is one of my accounts → self transfer', () {
      expect(SelfTransfer.detect(toOwn, '1234', {'5678'}), isTrue);
      expect(SelfTransfer.detect(toOwn, '1234', {'1234', '5678'}), isTrue);
    });

    test('only the SMS\'s own account matches → NOT a self transfer', () {
      expect(SelfTransfer.detect(toOwn, '1234', {'1234'}), isFalse);
      expect(
        SelfTransfer.detect(
          'Rs.450.00 debited from A/c XX1234 to VPA swiggy@axisbank',
          '1234',
          {'1234'},
        ),
        isFalse,
      );
    });

    test('no accounts saved → only the word "self" counts', () {
      expect(SelfTransfer.detect(toOwn, '1234', {}), isFalse);
      expect(
        SelfTransfer.detect(
          'Rs 1000 debited A/c XX1234 trf to SELF',
          '1234',
          {},
        ),
        isTrue,
      );
      expect(
        SelfTransfer.detect('Paid Rs 50 at self-service kiosk', null, {}),
        isFalse,
      );
    });

    test('3-digit masked number matches the end of my last 4', () {
      expect(
        SelfTransfer.detect(
          'Rs 200 credited to A/C X901 from A/c X678 by IMPS',
          '901',
          {'5678'},
        ),
        isTrue,
      );
    });

    test('long reference numbers are not account numbers', () {
      expect(
        SelfTransfer.accountNumbers(
          'Rs.450 debited from A/c XX1234. UPI Ref No 632456781234',
        ),
        ['1234'],
      );
    });
  });

  group('self transfers are never counted', () {
    final day = DateTime(2026, 11, 20, 10);
    TransactionModel txn(String type, int paise, {bool self = false}) =>
        TransactionModel(
          amountPaise: paise,
          type: type,
          categoryId: 1,
          paymentMode: 'UPI',
          dateTime: day,
          isSelfTransfer: self,
        );
    final txns = [
      txn('expense', 10000),
      txn('income', 50000),
      txn('expense', 500000, self: true),
      txn('income', 500000, self: true),
    ];

    test('dashboard', () {
      final s = DashboardSummary.compute(txns, day, (_) => null);
      expect(s.spentPaise, 10000);
      expect(s.incomePaise, 50000);
    });

    test('history totals and day groups', () {
      expect(HistoryProvider.totalsOf(txns), (10000, 50000));
      final g = TransactionProvider.groupByDay(txns).single;
      expect(g.items, hasLength(4)); // still listed
      expect(g.expensePaise, 10000);
      expect(g.incomePaise, 50000);
    });

    test('reports (still exported, marked Self transfer)', () {
      final r = ReportSummary.compute(txns, day, today: day);
      expect(r.spentPaise, 10000);
      expect(r.incomePaise, 50000);
      expect(r.transactions, hasLength(4));
      expect(ExportService.typeLabel(txns[2]), 'Self transfer');
      expect(ExportService.typeLabel(txns[0]), 'Expense');
    });
  });

  test('validateLast4', () {
    expect(validateLast4('1234'), isNull);
    expect(validateLast4(' 5678 '), isNull);
    expect(validateLast4(''), isNotNull);
    expect(validateLast4('123'), isNotNull);
    expect(validateLast4('12a4'), isNotNull);
  });
}
