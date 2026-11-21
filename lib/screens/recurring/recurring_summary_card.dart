import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/recurring_installment.dart';
import '../../models/recurring_payment.dart';
import '../../services/installment_schedule.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';
import 'recurring_tile.dart';

/// Top card on the detail screen: amount, schedule, status, progress and
/// (for chitti) organiser and lump-sum details.
class RecurringSummaryCard extends StatelessWidget {
  const RecurringSummaryCard({
    super.key,
    required this.item,
    required this.category,
    required this.state,
    required this.next,
    required this.progress,
  });

  final RecurringPayment item;
  final CategoryModel? category;
  final RecurringState state;
  final RecurringInstallment? next;
  final RecurringProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = item;
    final color = Color(category?.color ?? 0xFF757575);
    final fraction = progress.fraction;
    final received = p.chittiReceivedPaise;

    return Card(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    iconFor(category?.icon ?? 'category'),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        RecurringPayment.typeLabel(p.type),
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        formatPaise(p.amountPaise),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stateLabel(state, next),
              style: theme.textTheme.titleSmall?.copyWith(
                color: stateColor(state, cs),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                scheduleLabel(p),
                category?.name ?? 'Category',
                p.paymentMode,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (p.endDate != null)
              Text(
                'Ends ${DateFormat('d MMM yyyy').format(p.endDate!)}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            if (fraction != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: fraction, minHeight: 8),
              ),
              const SizedBox(height: 6),
            ],
            Text(progress.label, style: theme.textTheme.bodyMedium),
            if (p.isChitti &&
                (p.organiserName != null || p.organiserPhone != null)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        p.organiserName,
                        p.organiserPhone,
                      ].whereType<String>().join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (received != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.volunteer_activism, size: 18),
                label: Text(
                  'Chitti received ${formatPaise(received)}'
                  '${p.chittiReceivedDate == null ? '' : ' on ${DateFormat('d MMM yyyy').format(p.chittiReceivedDate!)}'}',
                ),
              ),
            ],
            if (p.notes != null) ...[
              const SizedBox(height: 8),
              Text(p.notes!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
