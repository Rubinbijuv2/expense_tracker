import 'package:expense_tracker/models/recurring_installment.dart';
import 'package:expense_tracker/models/recurring_payment.dart';
import 'package:expense_tracker/services/recurring_match.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPayment item({
  int id = 1,
  String name = 'Bike EMI',
  String type = 'emi',
  int amount = 450000,
  String? keyword,
  bool active = true,
}) => RecurringPayment(
  id: id,
  name: name,
  type: type,
  amountPaise: amount,
  categoryId: 1,
  dueDay: 5,
  startDate: DateTime(2026, 1, 1),
  paymentMode: 'UPI',
  matchKeyword: keyword,
  active: active,
);

RecurringInstallment inst(
  DateTime due, {
  int recId = 1,
  String s = 'pending',
}) => RecurringInstallment(id: 9, recurringId: recId, dueDate: due, status: s);

bool m(
  RecurringPayment p,
  RecurringInstallment i, {
  int? amount,
  DateTime? date,
  String text = 'debited',
}) => RecurringMatch.matches(
  p: p,
  inst: i,
  amountPaise: amount ?? p.amountPaise,
  date: date ?? DateTime(2026, 12, 5, 14),
  text: text,
);

void main() {
  final due = DateTime(2026, 12, 5);

  test('same amount within ±3 days matches', () {
    final p = item();
    expect(m(p, inst(due), date: DateTime(2026, 12, 2)), isTrue);
    expect(m(p, inst(due), date: DateTime(2026, 12, 8, 23)), isTrue);
  });

  test('more than 3 days away does not match', () {
    final p = item();
    expect(m(p, inst(due), date: DateTime(2026, 12, 1)), isFalse);
    expect(m(p, inst(due), date: DateTime(2026, 12, 9)), isFalse);
  });

  test('bill/EMI/fee need the exact amount', () {
    expect(m(item(), inst(due), amount: 450100), isFalse);
  });

  test('chitti allows ±20%', () {
    final p = item(type: 'chitti', amount: 500000);
    expect(m(p, inst(due), amount: 400000), isTrue); // -20%
    expect(m(p, inst(due), amount: 600000), isTrue); // +20%
    expect(m(p, inst(due), amount: 399900), isFalse);
    expect(m(p, inst(due), amount: 600100), isFalse);
  });

  test('match keyword must appear (any case) when set', () {
    final p = item(keyword: 'HDFC LOAN');
    expect(m(p, inst(due), text: 'Rs 4500 debited towards hdfc loan'), isTrue);
    expect(m(p, inst(due), text: 'Rs 4500 paid to Swiggy'), isFalse);
  });

  test('paid installments and paused items never match', () {
    expect(m(item(), inst(due, s: 'paid')), isFalse);
    expect(m(item(active: false), inst(due)), isFalse);
  });

  test('find: income never matches, closest due date wins', () {
    final a = item(id: 1, name: 'Rent', amount: 100000);
    final b = item(id: 2, name: 'Gym', amount: 100000);
    final insts = {
      1: [inst(DateTime(2026, 12, 3), recId: 1)],
      2: [inst(DateTime(2026, 12, 6), recId: 2)],
    };
    DueItem? find(String type) => RecurringMatch.find(
      items: [a, b],
      installments: insts,
      type: type,
      amountPaise: 100000,
      date: DateTime(2026, 12, 5),
      text: '',
    );
    expect(find('income'), isNull);
    expect(find('expense')!.item.name, 'Gym');
  });
}
