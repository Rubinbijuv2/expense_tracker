import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/detected_sms.dart';
import '../../utils/formatters.dart';
import 'kind_label.dart';

/// "Looks like the same payment" (PLAN.md rule 12): a Bank SMS and a
/// Receipt SMS with the same amount within 30 minutes, shown as ONE card
/// with both texts. A payment app notification takes the receipt's place
/// (PLAN.md 7.5): "Found in Google Pay and bank SMS".
///
/// **Merge** keeps the bank SMS's account and payment mode and the receipt's
/// merchant and category, leaving one normal card to Save or Edit.
class MergeCard extends StatelessWidget {
  const MergeCard({
    super.key,
    required this.bank,
    required this.receipt,
    required this.receiptCategory,
    required this.onMerge,
    required this.onNotSame,
    required this.onIgnoreBoth,
  });

  final DetectedSms bank;
  final DetectedSms receipt;
  final CategoryModel? receiptCategory;
  final VoidCallback onMerge;
  final VoidCallback onNotSame;
  final VoidCallback onIgnoreBoth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final merged = [
      receipt.merchant ?? 'Unknown',
      if (receiptCategory != null) receiptCategory!.name,
      if (bank.paymentMode != null) bank.paymentMode!,
      if (bank.accountLast4 != null) 'A/c ••${bank.accountLast4}',
    ].join(' · ');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.primary, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.merge_type, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    receipt.isNotification
                        ? 'Found in ${receipt.sourceApp ?? receipt.sender} '
                              'and bank SMS'
                        : 'Looks like the same payment',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${bank.type == 'income' ? '+' : '−'}'
                    '${formatPaise(bank.amountPaise)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: bank.type == 'income'
                          ? Colors.green.shade700
                          : scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('After merge: $merged', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            _SmsText(sms: bank),
            const SizedBox(height: 6),
            _SmsText(sms: receipt),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: onIgnoreBoth,
                  child: const Text('Ignore both'),
                ),
                OutlinedButton(
                  onPressed: onNotSame,
                  child: const Text('Not the same'),
                ),
                FilledButton.icon(
                  onPressed: onMerge,
                  icon: const Icon(Icons.merge_type, size: 18),
                  label: const Text('Merge'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two SMS inside the merge card: label, time and text.
class _SmsText extends StatelessWidget {
  const _SmsText({required this.sms});

  final DetectedSms sms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KindLabel(sms: sms),
              const SizedBox(width: 8),
              Text(
                DateFormat('h:mm a').format(sms.receivedAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${sms.sender}: ${sms.body}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
