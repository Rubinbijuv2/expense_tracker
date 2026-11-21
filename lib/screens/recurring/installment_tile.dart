import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recurring_installment.dart';
import '../../services/installment_schedule.dart';
import '../../utils/formatters.dart';

/// One row in the installment history on the detail screen.
class InstallmentTile extends StatelessWidget {
  const InstallmentTile({
    super.key,
    required this.inst,
    required this.number,
    required this.onTap,
  });

  final RecurringInstallment inst;
  final int number; // 1-based position in the schedule
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = InstallmentSchedule.dateOnly(DateTime.now());
    final late = inst.isPending && inst.dueDate.isBefore(today);

    final (IconData icon, Color color, String label) = switch (inst.status) {
      'paid' => (Icons.check_circle, Colors.green.shade600, 'Paid'),
      'skipped' => (Icons.redo, cs.outline, 'Skipped'),
      _ =>
        late
            ? (Icons.error_outline, cs.tertiary, 'Not paid')
            : (Icons.schedule, cs.primary, 'Pending'),
    };

    final paidAt = inst.paidAt;
    final subtitle = switch (inst.status) {
      'paid' => [
        if (paidAt != null) 'Paid ${DateFormat('d MMM yyyy').format(paidAt)}',
        if (inst.transactionId == null) 'no expense added',
      ].join(' · '),
      _ => label,
    };

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        '#$number · due ${DateFormat('d MMM yyyy').format(inst.dueDate)}',
      ),
      subtitle: Text(subtitle),
      trailing: inst.isPaid && inst.paidAmountPaise != null
          ? Text(
              formatPaise(inst.paidAmountPaise!),
              style: theme.textTheme.titleSmall,
            )
          : Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
    );
  }
}

/// Bottom sheet when an installment row is tapped. Returns 'pay', 'skip',
/// 'undo' or null (closed).
Future<String?> showInstallmentActions(
  BuildContext context,
  RecurringInstallment inst,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inst.isPending) ...[
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Mark as paid'),
              onTap: () => Navigator.pop(ctx, 'pay'),
            ),
            ListTile(
              leading: const Icon(Icons.redo),
              title: const Text('Skip'),
              onTap: () => Navigator.pop(ctx, 'skip'),
            ),
          ],
          if (inst.isPaid)
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Mark as not paid'),
              subtitle: inst.transactionId == null
                  ? null
                  : const Text('Also deletes the expense it added'),
              onTap: () => Navigator.pop(ctx, 'undo'),
            ),
          if (inst.isSkipped)
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Undo skip'),
              onTap: () => Navigator.pop(ctx, 'undo'),
            ),
        ],
      ),
    ),
  );
}
