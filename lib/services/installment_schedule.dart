import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import '../utils/formatters.dart';

/// What the list and detail screens show as an item's status.
enum RecurringState { paused, completed, late, dueToday, dueSoon, upcoming }

/// Pure date maths for repeat payments: due dates, progress and status.
/// No database and no Flutter, so it is easy to unit-test.
/// Every method that needs "today" takes it as a parameter for the same reason.
class InstallmentSchedule {
  InstallmentSchedule._();

  /// Midnight of [d] (drops the time).
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day; // day 0 = last day of previous month

  /// [day] in that month, moved back to the last day if the month is
  /// shorter (31 → 28/29 Feb, 31 → 30 Apr).
  static DateTime clampedDate(int year, int month, int day) {
    // DateTime(2026, 13) is fixed by Dart to Jan 2027, so normalise first.
    final first = DateTime(year, month);
    final last = daysInMonth(first.year, first.month);
    return DateTime(first.year, first.month, day > last ? last : day);
  }

  /// The [i]-th due date (0 = first), or null when the schedule has ended
  /// (past the end date or the total number of installments).
  ///
  /// Each date is worked out from the first one (not from the previous one),
  /// so a 31st that became 28 Feb goes back to 31 Mar.
  static DateTime? dueDateAt(RecurringPayment p, int i) {
    final total = p.totalInstallments;
    if (i < 0 || (total != null && i >= total)) return null;
    final start = dateOnly(p.startDate);
    late DateTime d;
    switch (p.frequency) {
      case 'weekly':
        // Days until the chosen weekday, 0–6.
        final offset = (p.dueDay - start.weekday) % 7;
        d = DateTime(start.year, start.month, start.day + offset + 7 * i);
      case 'yearly':
        var first = clampedDate(start.year, start.month, p.dueDay);
        if (first.isBefore(start)) {
          first = clampedDate(start.year + 1, start.month, p.dueDay);
        }
        d = clampedDate(first.year + i, first.month, p.dueDay);
      default: // monthly
        var month = start.month;
        if (clampedDate(start.year, month, p.dueDay).isBefore(start)) month++;
        d = clampedDate(start.year, month + i, p.dueDay);
    }
    final end = p.endDate;
    if (end != null && d.isAfter(dateOnly(end))) return null;
    return d;
  }

  /// Every due date from the start up to and including the first one on or
  /// after [until] (so the next upcoming payment is always included).
  static List<DateTime> datesThrough(RecurringPayment p, DateTime until) {
    final limit = dateOnly(until);
    final dates = <DateTime>[];
    // 5000 is only a safety net (≈ 96 years of weekly payments).
    for (var i = 0; i < 5000; i++) {
      final d = dueDateAt(p, i);
      if (d == null) break;
      dates.add(d);
      if (!d.isBefore(limit)) break;
    }
    return dates;
  }

  /// One key per period, so one month (or week, or year) never gets two
  /// installments, even after the due day is edited.
  static String periodKey(DateTime d, String frequency) {
    switch (frequency) {
      case 'weekly':
        final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        return 'w${monday.toIso8601String().substring(0, 10)}';
      case 'yearly':
        return 'y${d.year}';
      default:
        return 'm${monthKey(d)}';
    }
  }

  /// Due dates up to [until] whose period has no installment yet.
  static List<DateTime> missingDates(
    RecurringPayment p,
    List<RecurringInstallment> existing,
    DateTime until,
  ) {
    final have = {for (final e in existing) periodKey(e.dueDate, p.frequency)};
    return datesThrough(
      p,
      until,
    ).where((d) => !have.contains(periodKey(d, p.frequency))).toList();
  }

  /// The oldest pending installment (what "Mark as paid" and "Skip" act on).
  static RecurringInstallment? nextPending(List<RecurringInstallment> list) {
    RecurringInstallment? best;
    for (final i in list) {
      if (!i.isPending) continue;
      if (best == null || i.dueDate.isBefore(best.dueDate)) best = i;
    }
    return best;
  }

  static RecurringState stateOf(
    RecurringPayment p,
    List<RecurringInstallment> list,
    DateTime today,
  ) {
    if (!p.active) return RecurringState.paused;
    final next = nextPending(list);
    if (next == null) return RecurringState.completed;
    final days = next.dueDate.difference(dateOnly(today)).inDays;
    if (days < 0) return RecurringState.late;
    if (days == 0) return RecurringState.dueToday;
    if (days <= 7) return RecurringState.dueSoon;
    return RecurringState.upcoming;
  }

  /// Progress numbers and the text shown under the name.
  static RecurringProgress progressOf(
    RecurringPayment p,
    List<RecurringInstallment> list,
  ) {
    var paid = 0, skipped = 0, paidPaise = 0;
    for (final i in list) {
      if (i.isPaid) {
        paid++;
        paidPaise += i.paidAmountPaise ?? 0;
      } else if (i.isSkipped) {
        skipped++;
      }
    }
    return RecurringProgress(
      type: p.type,
      paidCount: paid,
      skippedCount: skipped,
      total: p.hasProgress ? p.totalInstallments : null,
      paidPaise: paidPaise,
      usualPaise: p.amountPaise,
    );
  }
}

/// How far an EMI or chitti has got, and the totals for any repeat payment.
class RecurringProgress {
  const RecurringProgress({
    required this.type,
    required this.paidCount,
    required this.skippedCount,
    required this.total,
    required this.paidPaise,
    required this.usualPaise,
  });

  final String type;
  final int paidCount;
  final int skippedCount;
  final int? total; // only for EMI / chitti
  final int paidPaise;
  final int usualPaise;

  /// Paid + skipped: months that are over.
  int get doneCount => paidCount + skippedCount;

  /// Months still to pay × usual amount (null when there is no total).
  int? get leftPaise {
    final t = total;
    if (t == null) return null;
    final left = t - doneCount;
    return (left < 0 ? 0 : left) * usualPaise;
  }

  /// 0.0–1.0 for the progress bar (null when there is no total).
  double? get fraction {
    final t = total;
    if (t == null || t == 0) return null;
    return (doneCount / t).clamp(0.0, 1.0);
  }

  /// "8 of 24 paid · ₹96,000 left" (EMI),
  /// "Month 12 of 40 · ₹60,000 paid · ₹1,40,000 left" (chitti),
  /// "3 payments · ₹600 paid" (others).
  String get label {
    final t = total;
    if (t != null && type == 'emi') {
      return '$paidCount of $t paid · ${shortRupees(leftPaise!)} left';
    }
    if (t != null && type == 'chitti') {
      return 'Month $doneCount of $t · ${shortRupees(paidPaise)} paid · '
          '${shortRupees(leftPaise!)} left';
    }
    if (paidCount == 0) return 'No payments yet';
    return '$paidCount payment${paidCount == 1 ? '' : 's'} · '
        '${shortRupees(paidPaise)} paid';
  }
}

/// "₹60,000" instead of "₹60,000.00" for whole rupees; paise kept otherwise.
String shortRupees(int paise) {
  final s = formatPaise(paise);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}
