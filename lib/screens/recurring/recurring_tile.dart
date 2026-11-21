import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/recurring_installment.dart';
import '../../models/recurring_payment.dart';
import '../../services/installment_schedule.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';

const List<String> weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "1st", "2nd", "23rd", "31st".
String ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// "Monthly on the 5th", "Every Monday", "Every year on 5 Mar".
String scheduleLabel(RecurringPayment p) => switch (p.frequency) {
  'weekly' => 'Every ${weekdayNames[p.dueDay - 1]}',
  'yearly' =>
    'Every year on ${DateFormat('d MMM').format(InstallmentSchedule.clampedDate(2001, p.startDate.month, p.dueDay))}',
  _ => 'Monthly on the ${ordinal(p.dueDay)}',
};

/// "Due in 3 days", "Due today", "Not paid · was due 5 Nov", ...
String stateLabel(RecurringState state, RecurringInstallment? next) {
  final d = next == null ? '' : DateFormat('d MMM').format(next.dueDate);
  return switch (state) {
    RecurringState.paused => 'Paused',
    RecurringState.completed => 'Completed',
    RecurringState.late => 'Not paid · was due $d',
    RecurringState.dueToday => 'Due today',
    RecurringState.dueSoon =>
      'Due $d (in ${next!.dueDate.difference(InstallmentSchedule.dateOnly(DateTime.now())).inDays} days)',
    RecurringState.upcoming => 'Next due $d',
  };
}

/// Colour for the status text (red "overdue" styling comes in step 13).
Color stateColor(RecurringState state, ColorScheme cs) => switch (state) {
  RecurringState.dueToday || RecurringState.dueSoon => cs.primary,
  RecurringState.late => cs.tertiary,
  _ => cs.onSurfaceVariant,
};

/// One row on the Repeat payments list.
class RecurringTile extends StatelessWidget {
  const RecurringTile({
    super.key,
    required this.item,
    required this.category,
    required this.state,
    required this.next,
    required this.progress,
    required this.onTap,
  });

  final RecurringPayment item;
  final CategoryModel? category;
  final RecurringState state;
  final RecurringInstallment? next;
  final RecurringProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = Color(category?.color ?? 0xFF757575);
    final muted = !item.active || state == RecurringState.completed;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: muted ? 0.06 : 0.15),
        child: Icon(
          iconFor(category?.icon ?? 'category'),
          color: muted ? cs.outline : color,
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stateLabel(state, next),
            style: theme.textTheme.bodySmall?.copyWith(
              color: stateColor(state, cs),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.hasProgress)
            Text(progress.label, style: theme.textTheme.bodySmall),
        ],
      ),
      isThreeLine: item.hasProgress,
      trailing: Text(
        formatPaise(item.amountPaise),
        style: theme.textTheme.titleSmall?.copyWith(
          color: muted ? cs.outline : null,
        ),
      ),
    );
  }
}
