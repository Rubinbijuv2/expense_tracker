import '../models/recurring_installment.dart';
import '../services/installment_schedule.dart';
import '../services/recurring_match.dart';
import 'recurring_provider.dart';

/// Read-only questions about repeat payments (Home card, budget forecast,
/// auto-match). An `extension` adds methods to an existing class from
/// another file, which keeps recurring_provider.dart short.
extension RecurringQueries on RecurringProvider {
  static DateTime get _today => InstallmentSchedule.dateOnly(DateTime.now());

  /// Active items with their oldest pending installment, soonest first.
  List<UpcomingItem> get upcoming {
    final list = <UpcomingItem>[];
    for (final p in items) {
      final next = nextPending(p.id!);
      if (p.active && next != null) list.add((item: p, next: next));
    }
    list.sort((a, b) => a.next.dueDate.compareTo(b.next.dueDate));
    return list;
  }

  /// Every unpaid installment of active items, oldest due date first, so
  /// overdue ones (due before today) always come first.
  List<UpcomingItem> get dueList {
    final list = <UpcomingItem>[];
    for (final p in items) {
      if (!p.active) continue;
      for (final i in installmentsOf(p.id!)) {
        if (i.isPending) list.add((item: p, next: i));
      }
    }
    list.sort((a, b) => a.next.dueDate.compareTo(b.next.dueDate));
    return list;
  }

  /// Unpaid installments whose due day has passed (shown in red).
  List<UpcomingItem> get overdue =>
      dueList.where((d) => d.next.dueDate.isBefore(_today)).toList();

  /// "₹X due this month": what is still to pay up to the end of this month,
  /// overdue ones included. Also the "upcoming" part of the budget forecast.
  int get dueThisMonthPaise {
    var total = 0;
    for (final p in items) {
      total += InstallmentSchedule.dueThisMonthPaise(
        p,
        installmentsOf(p.id!),
        _today,
      );
    }
    return total;
  }

  /// Auto-match: the repeat payment an expense probably paid, or null.
  UpcomingItem? matchFor({
    required String type,
    required int amountPaise,
    required DateTime date,
    required String text,
  }) => RecurringMatch.find(
    items: items,
    installments: allInstallments,
    type: type,
    amountPaise: amountPaise,
    date: date,
    text: text,
  );

  RecurringInstallment? installmentById(int recurringId, int installmentId) {
    for (final i in installmentsOf(recurringId)) {
      if (i.id == installmentId) return i;
    }
    return null;
  }
}
