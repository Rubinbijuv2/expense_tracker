import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/detected_sms.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';
import 'kind_label.dart';

/// One pending detected SMS: kind label, Save · Edit · Ignore and a ⋮ menu
/// with "Always ignore this sender" (PLAN.md rule 14).
///
/// A self transfer is drawn greyed, and its main button is
/// "Ignore (own transfer)" (rule 13).
///
/// When the SMS looks like a repeat payment (PLAN.md 5.3), a strip
/// "Mark Bike EMI as paid?" is shown; nothing happens until it is tapped.
class DetectedSmsCard extends StatelessWidget {
  const DetectedSmsCard({
    super.key,
    required this.sms,
    required this.category,
    required this.onSave,
    required this.onEdit,
    required this.onIgnore,
    required this.onIgnoreSender,
    this.matchName,
    this.onMarkPaid,
  });

  final DetectedSms sms;
  final CategoryModel? category; // the guessed category (null if none)
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onIgnore;
  final VoidCallback onIgnoreSender;

  /// Name of the repeat payment this SMS probably paid (null: no match).
  final String? matchName;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final self = sms.isSelfTransfer;
    final isExpense = sms.type == 'expense';
    final catColor = Color(category?.color ?? 0xFF757575);
    final amountColor = self
        ? scheme.outline
        : (isExpense ? scheme.error : Colors.green.shade600);
    final details = [
      if (sms.paymentMode != null) sms.paymentMode!,
      if (sms.accountLast4 != null) 'A/c ••${sms.accountLast4}',
      DateFormat('d MMM, h:mm a').format(sms.receivedAt),
    ].join(' · ');

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
              Text(
                '${isExpense ? '−' : '+'}${formatPaise(sms.amountPaise)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                  decoration: self ? TextDecoration.lineThrough : null,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (_) => onIgnoreSender(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'ignore_sender',
                    child: Text('Always ignore ${sms.sender}'),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KindLabel(sms: sms),
              Text(details, style: theme.textTheme.bodySmall),
            ],
          ),
          if (self)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Money moved between your own accounts. It is never counted '
                'in spending or income.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else ...[
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                iconFor(category?.icon ?? ''),
                size: 18,
                color: catColor,
              ),
              label: Text(category?.name ?? 'No category — tap Edit'),
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(height: 4),
          // The original SMS, so the user can check what was detected.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '${sms.sender}: ${sms.body}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!self && matchName != null && onMarkPaid != null)
            _matchStrip(theme, matchName!, onMarkPaid!),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: self ? _selfButtons() : _normalButtons(),
          ),
        ],
      ),
    );

    return Card(
      color: self ? scheme.surfaceContainerHighest : null,
      // Opacity draws the whole card see-through, so it looks greyed out.
      child: self ? Opacity(opacity: 0.75, child: content) : content,
    );
  }

  /// "Mark **Bike EMI** as paid?  [Mark paid]" — saves this SMS and links
  /// it to the repeat payment in one tap.
  Widget _matchStrip(ThemeData theme, String name, VoidCallback onTap) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 12),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
          child: Row(
            children: [
              Icon(Icons.event_repeat, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Mark '),
                      TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' as paid?'),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onTap, child: const Text('Mark paid')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _normalButtons() => Row(
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
  );

  Widget _selfButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        onPressed: category == null ? onEdit : onSave,
        child: const Text('Save anyway'),
      ),
      const SizedBox(width: 8),
      FilledButton.tonal(
        onPressed: onIgnore,
        child: const Text('Ignore (own transfer)'),
      ),
    ],
  );
}
