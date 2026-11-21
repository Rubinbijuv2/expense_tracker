import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/recurring_provider.dart';
import '../../services/installment_schedule.dart';
import '../../utils/formatters.dart';
import '../recurring/recurring_list_screen.dart';

/// Small "Upcoming" card on Home: how many repeat payments there are and
/// which one is due next. Tapping it opens the Repeat payments list.
/// (Step 13 turns this into the full card: next 3, total due, overdue.)
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecurringProvider>();
    if (rec.isLoading) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final upcoming = rec.upcoming;
    final active = rec.items.where((p) => p.active).length;

    final String subtitle;
    if (rec.items.isEmpty) {
      subtitle = 'Track bills, EMI, chitti and fees';
    } else if (upcoming.isEmpty) {
      subtitle = 'Nothing due';
    } else {
      final n = upcoming.first;
      final today = InstallmentSchedule.dateOnly(DateTime.now());
      final when = n.next.dueDate == today
          ? 'today'
          : '${n.next.dueDate.isBefore(today) ? 'was due' : 'on'} '
                '${DateFormat('d MMM').format(n.next.dueDate)}';
      subtitle =
          'Next: ${n.item.name} ${formatPaise(n.item.amountPaise)} $when';
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_repeat),
        title: Text(
          rec.items.isEmpty
              ? 'Repeat payments'
              : 'Upcoming · $active repeat payment${active == 1 ? '' : 's'}',
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => RecurringListScreen.open(context),
      ),
    );
  }
}
