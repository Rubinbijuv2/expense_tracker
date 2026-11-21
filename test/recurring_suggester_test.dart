import 'package:expense_tracker/models/recurring_payment.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/recurring_suggester.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel t(
  String merchant,
  int paise,
  DateTime date, {
  String type = 'expense',
  int? recurringId,
}) => TransactionModel(
  amountPaise: paise,
  type: type,
  categoryId: 5,
  paymentMode: 'UPI',
  dateTime: date,
  merchant: merchant,
  recurringId: recurringId,
);

List<RepeatSuggestion> run(
  List<TransactionModel> txns, {
  List<RecurringPayment> recurring = const [],
  Set<String> dismissed = const {},
}) => RecurringSuggester.suggest(
  transactions: txns,
  recurring: recurring,
  dismissed: dismissed,
  today: DateTime(2026, 11, 21),
);

void main() {
  final netflix3 = [
    t('Netflix', 19900, DateTime(2026, 9, 12)),
    t('Netflix', 19900, DateTime(2026, 10, 12)),
    t('netflix', 19900, DateTime(2026, 11, 12)),
  ];

  test('3 consecutive months with the same amount → suggestion', () {
    final s = run(netflix3);
    expect(s.length, 1);
    expect(s.first.merchant, 'netflix'); // latest spelling
    expect(s.first.amountPaise, 19900);
    expect(s.first.dueDay, 12);
    expect(s.first.categoryId, 5);
  });

  test('run ending last month still counts (not paid yet this month)', () {
    final s = run([
      t('Gym', 100000, DateTime(2026, 8, 3)),
      t('Gym', 100000, DateTime(2026, 9, 3)),
      t('Gym', 100000, DateTime(2026, 10, 3)),
    ]);
    expect(s.single.merchant, 'Gym');
  });

  test('±5% is similar, more is not', () {
    expect(
      run([
        t('Jio', 100000, DateTime(2026, 9, 1)),
        t('Jio', 105000, DateTime(2026, 10, 1)),
        t('Jio', 100000, DateTime(2026, 11, 1)),
      ]),
      hasLength(1),
    );
    expect(
      run([
        t('Jio', 100000, DateTime(2026, 9, 1)),
        t('Jio', 106000, DateTime(2026, 10, 1)),
        t('Jio', 100000, DateTime(2026, 11, 1)),
      ]),
      isEmpty,
    );
  });

  test('a gap month breaks the run', () {
    expect(
      run([
        t('Netflix', 19900, DateTime(2026, 8, 12)),
        t('Netflix', 19900, DateTime(2026, 10, 12)),
        t('Netflix', 19900, DateTime(2026, 11, 12)),
      ]),
      isEmpty,
    );
  });

  test('already a repeat payment, linked or dismissed → no suggestion', () {
    final rp = RecurringPayment(
      id: 1,
      name: 'Netflix',
      type: 'bill',
      amountPaise: 19900,
      categoryId: 5,
      dueDay: 12,
      startDate: DateTime(2026, 1, 1),
      paymentMode: 'UPI',
    );
    expect(run(netflix3, recurring: [rp]), isEmpty);
    expect(run(netflix3, dismissed: {'netflix'}), isEmpty);
    expect(
      run([
        ...netflix3,
        t('Netflix', 19900, DateTime(2026, 8, 12), recurringId: 1),
      ]),
      isEmpty,
    );
  });

  test('income and Unknown merchants are ignored', () {
    expect(
      run([
        for (final m in [9, 10, 11])
          t('Salary', 5000000, DateTime(2026, m, 1), type: 'income'),
        for (final m in [9, 10, 11]) t('Unknown', 5000, DateTime(2026, m, 1)),
      ]),
      isEmpty,
    );
  });
}
