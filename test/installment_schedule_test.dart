import 'package:expense_tracker/models/recurring_installment.dart';
import 'package:expense_tracker/models/recurring_payment.dart';
import 'package:expense_tracker/services/installment_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPayment item({
  String type = 'bill',
  String frequency = 'monthly',
  int dueDay = 5,
  DateTime? start,
  DateTime? end,
  int? total,
  int amount = 500000,
  bool active = true,
}) => RecurringPayment(
  id: 1,
  name: 'Test',
  type: type,
  amountPaise: amount,
  categoryId: 1,
  frequency: frequency,
  dueDay: dueDay,
  startDate: start ?? DateTime(2026, 1, 1),
  endDate: end,
  totalInstallments: total,
  paymentMode: 'UPI',
  active: active,
);

RecurringInstallment inst(
  DateTime due, {
  String status = 'pending',
  int? paid,
}) => RecurringInstallment(
  recurringId: 1,
  dueDate: due,
  status: status,
  paidAmountPaise: paid,
);

void main() {
  group('due dates', () {
    test('monthly: first due in start month when day is not past', () {
      final p = item(dueDay: 5, start: DateTime(2026, 1, 3));
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 1, 5));
      expect(InstallmentSchedule.dueDateAt(p, 1), DateTime(2026, 2, 5));
      expect(InstallmentSchedule.dueDateAt(p, 11), DateTime(2026, 12, 5));
      expect(InstallmentSchedule.dueDateAt(p, 12), DateTime(2027, 1, 5));
    });

    test('monthly: starts next month when due day already passed', () {
      final p = item(dueDay: 5, start: DateTime(2026, 1, 20));
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 2, 5));
    });

    test('monthly 31st becomes last day and goes back to 31st', () {
      final p = item(dueDay: 31, start: DateTime(2026, 1, 1));
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 1, 31));
      expect(InstallmentSchedule.dueDateAt(p, 1), DateTime(2026, 2, 28));
      expect(InstallmentSchedule.dueDateAt(p, 2), DateTime(2026, 3, 31));
      expect(InstallmentSchedule.dueDateAt(p, 3), DateTime(2026, 4, 30));
    });

    test('monthly 29th in a leap year February', () {
      final p = item(dueDay: 30, start: DateTime(2028, 2, 1));
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2028, 2, 29));
    });

    test('weekly: next chosen weekday, then every 7 days', () {
      // 1 Jan 2026 is a Thursday; due on Monday (1).
      final p = item(
        frequency: 'weekly',
        dueDay: 1,
        start: DateTime(2026, 1, 1),
      );
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 1, 5));
      expect(InstallmentSchedule.dueDateAt(p, 1), DateTime(2026, 1, 12));
      expect(InstallmentSchedule.dueDateAt(p, 0)!.weekday, DateTime.monday);
    });

    test('weekly: start day itself counts', () {
      final p = item(
        frequency: 'weekly',
        dueDay: 4,
        start: DateTime(2026, 1, 1),
      );
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 1, 1));
    });

    test('yearly: same day every year', () {
      final p = item(
        frequency: 'yearly',
        dueDay: 15,
        start: DateTime(2026, 3, 15),
      );
      expect(InstallmentSchedule.dueDateAt(p, 0), DateTime(2026, 3, 15));
      expect(InstallmentSchedule.dueDateAt(p, 2), DateTime(2028, 3, 15));
    });

    test('total installments stops the schedule', () {
      final p = item(type: 'emi', total: 3);
      expect(InstallmentSchedule.dueDateAt(p, 2), isNotNull);
      expect(InstallmentSchedule.dueDateAt(p, 3), isNull);
      expect(InstallmentSchedule.datesThrough(p, DateTime(2030)).length, 3);
    });

    test('end date stops the schedule', () {
      final p = item(dueDay: 5, end: DateTime(2026, 3, 5));
      expect(InstallmentSchedule.datesThrough(p, DateTime(2030)), [
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 5),
        DateTime(2026, 3, 5),
      ]);
    });
  });

  group('generation', () {
    test('datesThrough includes the next upcoming date', () {
      final p = item(dueDay: 5, start: DateTime(2026, 1, 1));
      final dates = InstallmentSchedule.datesThrough(p, DateTime(2026, 3, 10));
      expect(dates.last, DateTime(2026, 4, 5));
      expect(dates.length, 4);
    });

    test('due today is the last one generated', () {
      final p = item(dueDay: 5, start: DateTime(2026, 1, 1));
      final dates = InstallmentSchedule.datesThrough(p, DateTime(2026, 3, 5));
      expect(dates.last, DateTime(2026, 3, 5));
    });

    test('missingDates skips months that already have an installment', () {
      final p = item(dueDay: 10, start: DateTime(2026, 1, 1));
      // Feb was paid on the old due day (5th) before the due day was edited.
      final existing = [inst(DateTime(2026, 2, 5), status: 'paid', paid: 1)];
      final missing = InstallmentSchedule.missingDates(
        p,
        existing,
        DateTime(2026, 3, 1),
      );
      expect(missing, [DateTime(2026, 1, 10), DateTime(2026, 3, 10)]);
    });

    test('period keys', () {
      expect(
        InstallmentSchedule.periodKey(DateTime(2026, 2, 5), 'monthly'),
        'm2026-02',
      );
      expect(
        InstallmentSchedule.periodKey(DateTime(2026, 2, 5), 'yearly'),
        'y2026',
      );
      // Thu 1 Jan 2026 and Sun 4 Jan are the same week (Mon 29 Dec 2025).
      expect(
        InstallmentSchedule.periodKey(DateTime(2026, 1, 1), 'weekly'),
        InstallmentSchedule.periodKey(DateTime(2026, 1, 4), 'weekly'),
      );
    });
  });

  group('next pending and state', () {
    final today = DateTime(2026, 3, 10);

    test('oldest pending is next', () {
      final list = [
        inst(DateTime(2026, 1, 5), status: 'paid'),
        inst(DateTime(2026, 3, 5)),
        inst(DateTime(2026, 2, 5)),
      ];
      expect(
        InstallmentSchedule.nextPending(list)!.dueDate,
        DateTime(2026, 2, 5),
      );
    });

    test('states', () {
      final p = item();
      expect(
        InstallmentSchedule.stateOf(p, [inst(DateTime(2026, 3, 5))], today),
        RecurringState.late,
      );
      expect(
        InstallmentSchedule.stateOf(p, [inst(DateTime(2026, 3, 10))], today),
        RecurringState.dueToday,
      );
      expect(
        InstallmentSchedule.stateOf(p, [inst(DateTime(2026, 3, 15))], today),
        RecurringState.dueSoon,
      );
      expect(
        InstallmentSchedule.stateOf(p, [inst(DateTime(2026, 4, 5))], today),
        RecurringState.upcoming,
      );
      expect(
        InstallmentSchedule.stateOf(p, [], today),
        RecurringState.completed,
      );
      expect(
        InstallmentSchedule.stateOf(item(active: false), [
          inst(DateTime(2026, 4, 5)),
        ], today),
        RecurringState.paused,
      );
    });
  });

  group('progress', () {
    test('chitti: Month 12 of 40 · ₹60,000 paid · ₹1,40,000 left', () {
      final p = item(type: 'chitti', total: 40, amount: 500000);
      final list = [
        for (var m = 1; m <= 12; m++)
          inst(DateTime(2026, m, 5), status: 'paid', paid: 500000),
        inst(DateTime(2027, 1, 5)),
      ];
      final pr = InstallmentSchedule.progressOf(p, list);
      expect(pr.label, 'Month 12 of 40 · ₹60,000 paid · ₹1,40,000 left');
      expect(pr.fraction, closeTo(0.3, 0.0001));
    });

    test('chitti paid amounts can differ each month', () {
      final p = item(type: 'chitti', total: 10, amount: 100000);
      final list = [
        inst(DateTime(2026, 1, 5), status: 'paid', paid: 90000),
        inst(DateTime(2026, 2, 5), status: 'paid', paid: 85050),
      ];
      expect(
        InstallmentSchedule.progressOf(p, list).label,
        'Month 2 of 10 · ₹1,750.50 paid · ₹8,000 left',
      );
    });

    test('EMI: 8 of 24 paid · ₹96,000 left', () {
      final p = item(type: 'emi', total: 24, amount: 600000);
      final list = [
        for (var m = 1; m <= 8; m++)
          inst(DateTime(2026, m, 5), status: 'paid', paid: 600000),
      ];
      expect(
        InstallmentSchedule.progressOf(p, list).label,
        '8 of 24 paid · ₹96,000 left',
      );
    });

    test('skipped months count as done, not as paid', () {
      final p = item(type: 'emi', total: 4, amount: 100000);
      final list = [
        inst(DateTime(2026, 1, 5), status: 'paid', paid: 100000),
        inst(DateTime(2026, 2, 5), status: 'skipped'),
      ];
      final pr = InstallmentSchedule.progressOf(p, list);
      expect(pr.paidCount, 1);
      expect(pr.doneCount, 2);
      expect(pr.leftPaise, 200000);
    });

    test('bill without total shows payments count', () {
      final p = item(amount: 19900);
      expect(InstallmentSchedule.progressOf(p, []).label, 'No payments yet');
      expect(
        InstallmentSchedule.progressOf(p, [
          inst(DateTime(2026, 1, 5), status: 'paid', paid: 19900),
          inst(DateTime(2026, 2, 5), status: 'paid', paid: 19900),
        ]).label,
        '2 payments · ₹398 paid',
      );
    });
  });

  test('model toMap / fromMap round trip', () {
    final p = item(type: 'chitti', total: 40, end: null);
    final back = RecurringPayment.fromMap(p.toMap());
    expect(back.toMap(), p.toMap());
    final i = inst(DateTime(2026, 1, 5), status: 'paid', paid: 100);
    expect(RecurringInstallment.fromMap(i.toMap()).toMap(), i.toMap());
  });
}
