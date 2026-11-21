import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/recurring_provider.dart';
import '../../services/installment_schedule.dart';
import '../recurring/recurring_detail_screen.dart';
import '../recurring/recurring_list_screen.dart';

/// "Upcoming" card on Home (PLAN.md 5.4): overdue repeat payments first in
/// red, then the next 3 due, and "₹X due this month". Tapping the header
/// opens the Repeat payments list; tapping a row opens that payment.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({super.key});

  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecurringProvider>();
    if (rec.isLoading) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = InstallmentSchedule.dateOnly(DateTime.now());

    final all = rec.dueList;
    final overdue = all.where((d) => d.next.dueDate.isBefore(today)).toList();
    final next = all
        .where((d) => !d.next.dueDate.isBefore(today))
        .take(_maxRows)
        .toList();
    final dueMonth = rec.dueThisMonthPaise;

    final String subtitle;
    if (rec.items.isEmpty) {
      subtitle = 'Track bills, EMI, chitti and fees';
    } else if (all.isEmpty) {
      subtitle = 'Nothing due';
    } else {
      subtitle = dueMonth > 0
          ? '${shortRupees(dueMonth)} due this month'
          : 'Nothing more due this month';
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: Text(rec.items.isEmpty ? 'Repeat payments' : 'Upcoming'),
            subtitle: Text(
              overdue.isEmpty
                  ? subtitle
                  : '${overdue.length} overdue · $subtitle',
              style: theme.textTheme.bodySmall?.copyWith(
                color: overdue.isEmpty ? null : cs.error,
                fontWeight: overdue.isEmpty ? null : FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => RecurringListScreen.open(context),
          ),
          for (final d in overdue.take(_maxRows))
            _row(context, d, today, overdue: true),
          if (overdue.length > _maxRows)
            Padding(
              padding: const EdgeInsets.only(left: 72, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${overdue.length - _maxRows} more overdue',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ),
            ),
          for (final d in next) _row(context, d, today, overdue: false),
          if (overdue.isNotEmpty || next.isNotEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    UpcomingItem d,
    DateTime today, {
    required bool overdue,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final due = d.next.dueDate;
    final days = due.difference(today).inDays;
    final when = overdue
        ? 'Overdue · was due ${DateFormat('d MMM').format(due)}'
        : switch (days) {
            0 => 'Due today',
            1 => 'Due tomorrow',
            _ => 'Due ${DateFormat('EEE, d MMM').format(due)}',
          };
    final color = overdue ? cs.error : null;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        overdue ? Icons.warning_amber_rounded : Icons.schedule,
        size: 20,
        color: overdue ? cs.error : cs.onSurfaceVariant,
      ),
      title: Text(
        d.item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color),
      ),
      subtitle: Text(
        when,
        style: theme.textTheme.bodySmall?.copyWith(
          color: overdue ? cs.error : (days == 0 ? cs.primary : null),
        ),
      ),
      trailing: Text(
        shortRupees(d.item.amountPaise),
        style: theme.textTheme.titleSmall?.copyWith(color: color),
      ),
      onTap: () => RecurringDetailScreen.open(context, d.item.id!),
    );
  }
}
