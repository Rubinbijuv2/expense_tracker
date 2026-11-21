import 'package:expense_tracker/models/transaction_filter.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/providers/history_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionFilter.toWhere', () {
    test('empty filter gives no WHERE (all rows)', () {
      final (where, args) = const TransactionFilter().toWhere();
      expect(where, isNull);
      expect(args, isEmpty);
    });

    test('blank search text is ignored', () {
      final (where, _) = const TransactionFilter(query: '   ').toWhere();
      expect(where, isNull);
    });

    test('search matches note OR merchant with one ? each', () {
      final (where, args) = const TransactionFilter(query: ' swiggy ')
          .toWhere();
      expect(where, r"(note LIKE ? ESCAPE '\' OR merchant LIKE ? ESCAPE '\')");
      expect(args, ['%swiggy%', '%swiggy%']);
    });

    test('% and _ in search text are escaped, never put into SQL', () {
      final (where, args) = const TransactionFilter(query: "50%_off' OR 1=1")
          .toWhere();
      expect(where, isNot(contains('OR 1=1')));
      expect(args.first, r"%50\%\_off' OR 1=1%");
    });

    test('date range covers whole days, from inclusive to inclusive', () {
      final f = TransactionFilter(
        from: DateTime(2026, 11, 1, 15, 30), // time is ignored
        to: DateTime(2026, 11, 15, 9),
      );
      final (where, args) = f.toWhere();
      expect(where, 'date_time >= ? AND date_time < ?');
      expect(args, [
        DateTime(2026, 11, 1).toIso8601String(),
        DateTime(2026, 11, 16).toIso8601String(), // start of next day
      ]);
      // A transaction late on the "to" day is inside the range.
      final late = DateTime(2026, 11, 15, 23, 59).toIso8601String();
      expect(late.compareTo(args[1] as String) < 0, isTrue);
    });

    test('date range across month end', () {
      final f = TransactionFilter(to: DateTime(2026, 12, 31));
      final (_, args) = f.toWhere();
      expect(args, [DateTime(2027, 1, 1).toIso8601String()]);
    });

    test('categories and modes use IN with one ? per value', () {
      const f = TransactionFilter(
        categoryIds: {3, 1},
        paymentModes: {'UPI', 'Cash'},
      );
      final (where, args) = f.toWhere();
      expect(where, 'category_id IN (?, ?) AND payment_mode IN (?, ?)');
      expect(args, [1, 3, 'Cash', 'UPI']);
    });

    test('amount range in paise, both ends included', () {
      const f = TransactionFilter(minPaise: 10000, maxPaise: 50000);
      final (where, args) = f.toWhere();
      expect(where, 'amount_paise >= ? AND amount_paise <= ?');
      expect(args, [10000, 50000]);
    });

    test('only min amount', () {
      final (where, args) = const TransactionFilter(minPaise: 0).toWhere();
      expect(where, 'amount_paise >= ?');
      expect(args, [0]);
    });

    test('type filter', () {
      final (where, args) = const TransactionFilter(type: 'income').toWhere();
      expect(where, 'type = ?');
      expect(args, ['income']);
    });

    test('everything combined: placeholders match values', () {
      final f = TransactionFilter(
        query: 'zomato',
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        categoryIds: const {1},
        paymentModes: const {'UPI'},
        minPaise: 100,
        maxPaise: 99900,
        type: 'expense',
      );
      final (where, args) = f.toWhere();
      expect('?'.allMatches(where!).length, args.length);
      expect(args.length, 9);
      expect(where.split(' AND ').length, 8);
    });
  });

  group('TransactionFilter helpers', () {
    test('activeCount counts each kind of filter once', () {
      const none = TransactionFilter(query: 'abc');
      expect(none.activeCount, 0);
      expect(none.isEmpty, isFalse);

      final all = TransactionFilter(
        from: DateTime(2026),
        categoryIds: const {1, 2, 3},
        paymentModes: const {'UPI'},
        maxPaise: 5,
        type: 'expense',
      );
      expect(all.activeCount, 5);
    });

    test('copyWith clear flags remove values, others stay', () {
      final f = TransactionFilter(
        query: 'q',
        from: DateTime(2026),
        to: DateTime(2026, 2),
        minPaise: 1,
        maxPaise: 2,
        type: 'income',
      );
      final g = f.copyWith(clearDates: true, clearAmounts: true);
      expect(g.from, isNull);
      expect(g.to, isNull);
      expect(g.minPaise, isNull);
      expect(g.maxPaise, isNull);
      expect(g.type, 'income');
      expect(g.query, 'q');
      expect(f.copyWith(clearType: true).type, isNull);
    });

    test('clearFilters keeps the search text', () {
      const f = TransactionFilter(query: 'uber', type: 'expense');
      final g = f.clearFilters();
      expect(g.query, 'uber');
      expect(g.hasFilters, isFalse);
    });

    test('escapeLike escapes backslash first', () {
      expect(TransactionFilter.escapeLike(r'a\b%c_d'), r'a\\b\%c\_d');
    });
  });

  test('HistoryProvider.totalsOf sums expense and income separately', () {
    TransactionModel t(int paise, String type) => TransactionModel(
      amountPaise: paise,
      type: type,
      categoryId: 1,
      paymentMode: 'UPI',
      dateTime: DateTime(2026, 11, 1),
    );
    expect(HistoryProvider.totalsOf([]), (0, 0));
    expect(
      HistoryProvider.totalsOf([
        t(12550, 'expense'),
        t(50000, 'income'),
        t(450, 'expense'),
      ]),
      (13000, 50000),
    );
  });
}
