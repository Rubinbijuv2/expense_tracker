import 'package:intl/intl.dart';

import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import 'installment_schedule.dart';

/// One reminder notification to schedule for a repeat payment.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.recurringId,
    required this.installmentId,
    required this.isChitti,
    required this.hasPhone,
  });

  final int id; // notification id (see ReminderPlanner.idFor)
  final DateTime at; // local time
  final String title;
  final String body;
  final int recurringId;
  final int installmentId;
  final bool isChitti;
  final bool hasPhone; // chitti with an organiser phone → "Call organiser"

  /// Put on the notification so a tap knows which payment it is about.
  String get payload => ReminderPayload(recurringId, installmentId).encode();
}

/// `rec:RECURRING_ID:INSTALLMENT_ID` — tells reminder taps apart from
/// detected-SMS taps (whose payload is just the SMS id).
class ReminderPayload {
  const ReminderPayload(this.recurringId, this.installmentId);

  final int recurringId;
  final int installmentId;

  String encode() => 'rec:$recurringId:$installmentId';

  /// Null when [payload] is not a reminder payload.
  static ReminderPayload? parse(String? payload) {
    final parts = (payload ?? '').split(':');
    if (parts.length != 3 || parts[0] != 'rec') return null;
    final r = int.tryParse(parts[1]), i = int.tryParse(parts[2]);
    return r == null || i == null ? null : ReminderPayload(r, i);
  }
}

/// Pure rules for repeat-payment reminders (PLAN.md section 5.2):
/// 9:00 AM N days before, 9:00 AM on the due day, and 9:00 AM on each of
/// the 3 days after it while it is still unpaid (overdue).
class ReminderPlanner {
  ReminderPlanner._();

  static const int hour = 9;
  static const int overdueDays = 3;

  /// Android allows about 500 alarms per app; stay far below that.
  static const int maxReminders = 60;

  /// Reminder ids start here (SMS: 1000+, budgets: 1000000+).
  static const int idBase = 2000000;

  /// Slots per installment: 0 = before, 1 = due day, 2–4 = overdue days.
  static const int _slots = 8;

  /// Id used by the Developer "Fire a reminder now" test.
  static const int testId = idBase - 1;

  static int idFor(int installmentId, int slot) =>
      idBase + installmentId * _slots + slot;

  /// Every id a single installment may use (to cancel them after paying).
  static List<int> idsForInstallment(int installmentId) => [
    for (var s = 0; s < 2 + overdueDays; s++) idFor(installmentId, s),
  ];

  static bool isReminderId(int id) => id >= testId;

  /// Reminders still in the future, soonest first.
  static List<PlannedReminder> plan({
    required List<RecurringPayment> items,
    required Map<int, List<RecurringInstallment>> installments,
    required DateTime now,
  }) {
    final list = <PlannedReminder>[];
    for (final p in items) {
      if (!p.active || p.id == null) continue;
      for (final inst in installments[p.id] ?? const <RecurringInstallment>[]) {
        if (!inst.isPending || inst.id == null) continue;
        list.addAll(_forInstallment(p, inst, now));
      }
    }
    list.sort((a, b) => a.at.compareTo(b.at));
    return list.length > maxReminders ? list.sublist(0, maxReminders) : list;
  }

  static List<PlannedReminder> _forInstallment(
    RecurringPayment p,
    RecurringInstallment inst,
    DateTime now,
  ) {
    final due = InstallmentSchedule.dateOnly(inst.dueDate);
    final amount = shortRupees(p.amountPaise);
    final dueText = DateFormat('d MMM').format(due);
    final out = <PlannedReminder>[];

    void add(int slot, int dayOffset, String title, String body) {
      final at = DateTime(due.year, due.month, due.day + dayOffset, hour);
      if (!at.isAfter(now)) return;
      out.add(
        PlannedReminder(
          id: idFor(inst.id!, slot),
          at: at,
          title: title,
          body: body,
          recurringId: p.id!,
          installmentId: inst.id!,
          isChitti: p.isChitti,
          hasPhone: (p.organiserPhone ?? '').trim().isNotEmpty,
        ),
      );
    }

    final n = p.remindDaysBefore;
    if (n > 0) {
      add(
        0,
        -n,
        '${p.name} $amount due ${n == 1 ? 'tomorrow' : 'in $n days'}',
        'Due on $dueText',
      );
    }
    add(1, 0, '${p.name} $amount due today', 'Due today, $dueText');
    for (var d = 1; d <= overdueDays; d++) {
      add(
        1 + d,
        d,
        '${p.name} $amount is overdue',
        'Was due $dueText (${d == 1 ? '1 day' : '$d days'} ago)',
      );
    }
    return out;
  }
}
