import 'package:flutter/material.dart';

import '../../models/report_summary.dart';
import '../../utils/formatters.dart';

/// Three small figures in a row: Spent · Income · Avg / day.
class ReportStatsRow extends StatelessWidget {
  const ReportStatsRow({super.key, required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _Stat(label: 'Spent', value: formatPaise(summary.spentPaise)),
            _Stat(label: 'Income', value: formatPaise(summary.incomePaise)),
            _Stat(
              label: summary.daysCounted == 0
                  ? 'Avg / day'
                  : 'Avg / day (${summary.daysCounted} days)',
              value: formatPaise(summary.averagePerDayPaise),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          // FittedBox shrinks big amounts instead of cutting them off.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 5 merchants where the most money went this month.
class TopMerchantsCard extends StatelessWidget {
  const TopMerchantsCard({super.key, required this.merchants});

  /// Biggest first.
  final List<MerchantTotal> merchants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = merchants.isEmpty ? 0 : merchants.first.totalPaise;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top merchants', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (merchants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No spending this month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (var i = 0; i < merchants.length; i++)
                _MerchantRow(rank: i + 1, merchant: merchants[i], ofTop: top),
          ],
        ),
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.rank,
    required this.merchant,
    required this.ofTop,
  });

  final int rank;
  final MerchantTotal merchant;
  final int ofTop; // the #1 merchant's total, so its bar is full width

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = merchant.count;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      formatPaise(merchant.totalPaise),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ofTop == 0 ? 0 : merchant.totalPaise / ofTop,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'payment' : 'payments'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
