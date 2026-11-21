import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/detected_sms.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';

/// One pending detected SMS with Ignore / Edit / Save buttons.
class DetectedSmsCard extends StatelessWidget {
  const DetectedSmsCard({
    super.key,
    required this.sms,
    required this.category,
    required this.onSave,
    required this.onEdit,
    required this.onIgnore,
  });

  final DetectedSms sms;
  final CategoryModel? category; // the guessed category (null if none)
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isExpense = sms.type == 'expense';
    final catColor = Color(category?.color ?? 0xFF757575);
    final details = [
      if (sms.paymentMode != null) sms.paymentMode!,
      if (sms.accountLast4 != null) 'A/c ••${sms.accountLast4}',
      DateFormat('d MMM, h:mm a').format(sms.receivedAt),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sms.merchant ?? 'Unknown',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${isExpense ? '−' : '+'}${formatPaise(sms.amountPaise)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isExpense ? scheme.error : Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(details, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(iconFor(category?.icon ?? ''),
                  size: 18, color: catColor),
              label: Text(category?.name ?? 'No category — tap Edit'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 4),
            // The original SMS, so the user can check what was detected.
            Text(
              '${sms.sender}: ${sms.body}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onIgnore, child: const Text('Ignore')),
                const SizedBox(width: 4),
                OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                const SizedBox(width: 8),
                FilledButton(
                  // Without a category we can't save directly: open Edit.
                  onPressed: category == null ? onEdit : onSave,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
