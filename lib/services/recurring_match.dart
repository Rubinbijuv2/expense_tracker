import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import 'installment_schedule.dart';

/// A repeat payment with one of its installments (same shape as
/// RecurringProvider's UpcomingItem, so the two can be used interchangeably).
typedef DueItem = ({RecurringPayment item, RecurringInstallment next});

/// Pure auto-match rules (PLAN.md section 5.3). Used to suggest
/// "Mark Bike EMI as paid?" — the app never marks anything without a tap.
class RecurringMatch {
  RecurringMatch._();

  static const int maxDaysAway = 3;
  static const int chittiPercent = 20;

  /// True if an expense of [amountPaise] on [date] with [text] (SMS body,
  /// merchant, note) fits installment [inst] of [p].
  static bool matches({
    required RecurringPayment p,
    required RecurringInstallment inst,
    required int amountPaise,
    required DateTime date,
    required String text,
  }) {
    if (!p.active || !inst.isPending) return false;
    final days = InstallmentSchedule.dateOnly(date)
        .difference(InstallmentSchedule.dateOnly(inst.dueDate))
        .inDays
        .abs();
    if (days > maxDaysAway) return false;

    if (p.isChitti) {
      // Chitti amount changes every month: allow ±20%.
      final diff = (amountPaise - p.amountPaise).abs();
      if (diff * 100 > p.amountPaise * chittiPercent) return false;
    } else if (amountPaise != p.amountPaise) {
      return false;
    }

    final keyword = (p.matchKeyword ?? '').trim().toLowerCase();
    return keyword.isEmpty || text.toLowerCase().contains(keyword);
  }

  /// The best match (closest due date) among all pending installments,
  /// or null. Only expenses can pay a repeat payment.
  static DueItem? find({
    required List<RecurringPayment> items,
    required Map<int, List<RecurringInstallment>> installments,
    required String type,
    required int amountPaise,
    required DateTime date,
    required String text,
  }) {
    if (type != 'expense') return null;
    DueItem? best;
    var bestDays = 1 << 30;
    for (final p in items) {
      for (final inst in installments[p.id] ?? const <RecurringInstallment>[]) {
        final ok = matches(
          p: p,
          inst: inst,
          amountPaise: amountPaise,
          date: date,
          text: text,
        );
        if (!ok) continue;
        final days = date.difference(inst.dueDate).inDays.abs();
        if (days < bestDays) {
          best = (item: p, next: inst);
          bestDays = days;
        }
      }
    }
    return best;
  }
}
