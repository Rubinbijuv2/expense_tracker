import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../widgets/budget_progress.dart';

/// Full-width overall budget bar on Home: "₹X of ₹Y used · Z%".
/// Shows "Set a monthly budget" when none is set. Tap opens Budgets.
class BudgetBarCard extends StatelessWidget {
  const BudgetBarCard({
    super.key,
    required this.spentPaise,
    required this.limitPaise,
    required this.onTap,
  });

  final int spentPaise;

  /// Null when no overall budget is set for the month.
  final int? limitPaise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = limitPaise;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: limit == null
              ? Row(children: [
                  Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Set a monthly budget')),
                  const Icon(Icons.chevron_right),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text('Monthly budget',
                            style: theme.textTheme.titleSmall),
                      ),
                      Text(
                        '${budgetPercent(spentPaise, limit)}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: budgetColor(
                              context, budgetLevel(spentPaise, limit)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    BudgetProgressBar(
                        spentPaise: spentPaise, limitPaise: limit),
                    const SizedBox(height: 6),
                    Text(
                      '${formatPaise(spentPaise)} of ${formatPaise(limit)} used',
                      style: muted,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
