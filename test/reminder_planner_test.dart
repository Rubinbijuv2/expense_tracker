import 'package:expense_tracker/models/recurring_installment.dart';
import 'package:expense_tracker/models/recurring_payment.dart';
import 'package:expense_tracker/services/installment_schedule.dart';
import 'package:expense_tracker/services/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPayment item({
  int id = 1,
  String name = 'Tuition fee',
  String type = 'fee',
  int amount = 200000,
  int remind = 1,
  bool active = true,
  String? phone,
}) => RecurringPayment(
  id: id,
  name: name,
  type: type,
  amountPaise: amount,
  categoryId: 1,
  dueDay: 10,
  startDate: DateTime(2026, 1, 1),
  remindDaysBefore: remind,
  paymentMode: 'UPI',
  organiserPhone: phone,
  active: active,
);

RecurringInstallment inst(int id, DateTime due, {String status = 'pending'}) =>
    RecurringInstallment(id: id, recurringId: 1, dueDate: due, status: status);

List<PlannedReminder> planFor(
  RecurringPayment p,
  List<RecurringInstallment> list,
  DateTime now,
) => ReminderPlanner.plan(items: [p], installments: {p.id!: list}, now: now);

void main() {
  final due = DateTime(2026, 12, 10);

  test('before, due day and 3 overdue days, all at 9 AM', () {
    final r = planFor(item(), [inst(7, due)], DateTime(2026, 12, 1));
    expect(r.map((x) => x.at).toList(), [
      DateTime(2026, 12, 9, 9),
      DateTime(2026, 12, 10, 9),
      DateTime(2026, 12, 11, 9),
      DateTime(2026, 12, 12, 9),
      DateTime(2026, 12, 13, 9),
    ]);
    expect(r[0].title, 'Tuition fee ₹2,000 due tomorrow');
    expect(r[1].title, 'Tuition fee ₹2,000 due today');
    expect(r[2].title, 'Tuition fee ₹2,000 is overdue');
    expect(r[4].body, 'Was due 10 Dec (3 days ago)');
  });

  test('N days before uses "in N days"', () {
    final r = planFor(item(remind: 3), [inst(7, due)], DateTime(2026, 12, 1));
    expect(r.first.at, DateTime(2026, 12, 7, 9));
    expect(r.first.title, 'Tuition fee ₹2,000 due in 3 days');
  });

  test('remind 0 days before: no "before" reminder', () {
    final r = planFor(item(remind: 0), [inst(7, due)], DateTime(2026, 12, 1));
    expect(r.length, 4);
    expect(r.first.at, DateTime(2026, 12, 10, 9));
  });

  test('past times are skipped (10 AM on the due day)', () {
    final r = planFor(item(), [inst(7, due)], DateTime(2026, 12, 10, 10));
    expect(r.map((x) => x.at.day).toList(), [11, 12, 13]);
  });

  test('nothing after the 3 overdue days', () {
    final r = planFor(item(), [inst(7, due)], DateTime(2026, 12, 14));
    expect(r, isEmpty);
  });

  test('paid installments and paused items get no reminders', () {
    final now = DateTime(2026, 12, 1);
    expect(planFor(item(), [inst(7, due, status: 'paid')], now), isEmpty);
    expect(planFor(item(active: false), [inst(7, due)], now), isEmpty);
  });

  test(
    'ids are unique per installment and slot, and in the reminder range',
    () {
      final r = planFor(item(), [
        inst(7, due),
        inst(8, DateTime(2027, 1, 10)),
      ], DateTime(2026, 12, 1));
      final ids = r.map((x) => x.id).toSet();
      expect(ids.length, r.length);
      expect(ids.every(ReminderPlanner.isReminderId), isTrue);
      expect(
        ReminderPlanner.idsForInstallment(7),
        containsAll(r.where((x) => x.installmentId == 7).map((x) => x.id)),
      );
      // Budget alert ids (1000000 + id) are never treated as reminders.
      expect(ReminderPlanner.isReminderId(1000005), isFalse);
    },
  );

  test('chitti with phone gets the Call organiser flag', () {
    final r = planFor(item(type: 'chitti', phone: '9876543210'), [
      inst(7, due),
    ], DateTime(2026, 12, 1));
    expect(r.first.isChitti, isTrue);
    expect(r.first.hasPhone, isTrue);
  });

  test('payload round trip', () {
    const p = ReminderPayload(3, 42);
    final back = ReminderPayload.parse(p.encode())!;
    expect(back.recurringId, 3);
    expect(back.installmentId, 42);
    expect(ReminderPayload.parse('15'), isNull); // detected SMS payload
    expect(ReminderPayload.parse(null), isNull);
  });

  group('dueThisMonthPaise', () {
    final today = DateTime(2026, 12, 5);

    test('pending this month + overdue from last month', () {
      final p = item(amount: 100000);
      final list = [
        inst(1, DateTime(2026, 11, 10)), // overdue
        inst(2, DateTime(2026, 12, 10)), // this month
      ];
      expect(InstallmentSchedule.dueThisMonthPaise(p, list, today), 200000);
    });

    test('paid ones and next month are not counted', () {
      final p = item(amount: 100000);
      final list = [inst(2, DateTime(2026, 12, 10), status: 'paid')];
      expect(InstallmentSchedule.dueThisMonthPaise(p, list, today), 0);
    });

    test('weekly: later weeks of the month without installments count', () {
      final p = RecurringPayment(
        id: 1,
        name: 'Class',
        type: 'fee',
        amountPaise: 50000,
        categoryId: 1,
        frequency: 'weekly',
        dueDay: 1, // Mondays: 7, 14, 21, 28 Dec 2026
        startDate: DateTime(2026, 11, 1),
        paymentMode: 'Cash',
      );
      final list = [inst(1, DateTime(2026, 12, 7))];
      expect(InstallmentSchedule.dueThisMonthPaise(p, list, today), 200000);
    });
  });
}
