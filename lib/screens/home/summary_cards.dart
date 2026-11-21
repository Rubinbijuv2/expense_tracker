import 'package:flutter/material.dart';

import '../../utils/formatters.dart';

/// Spent / Income / Balance / Budget left, as a 2×2 grid of small cards.
class SummaryCards extends StatelessWidget {
  const SummaryCards({
    super.key,
    required this.spentPaise,
    required this.incomePaise,
    required this.balancePaise,
    required this.budgetLimitPaise,
  });

  final int spentPaise;
  final int incomePaise;
  final int balancePaise;

  /// Null when no overall budget is set for the month.
  final int? budgetLimitPaise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = Colors.green.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(children: [
            _StatCard(
              label: 'Spent',
              icon: Icons.arrow_upward,
              value: formatPaise(spentPaise),
              color: scheme.error,
            ),
            _StatCard(
              label: 'Income',
              icon: Icons.arrow_downward,
              value: formatPaise(incomePaise),
              color: green,
            ),
          ]),
          Row(children: [
            _StatCard(
              label: 'Balance',
              icon: Icons.account_balance_wallet_outlined,
              value: formatPaise(balancePaise),
              color: balancePaise < 0 ? scheme.error : scheme.onSurface,
            ),
            _buildBudgetCard(context),
          ]),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final limit = budgetLimitPaise;
    if (limit == null || limit <= 0) {
      return _StatCard(
        label: 'Budget left',
        icon: Icons.savings_outlined,
        value: 'Set a budget',
        color: scheme.onSurfaceVariant,
      );
    }

    // The coloured bar is in BudgetBarCard just below these cards.
    final left = limit - spentPaise;
    return _StatCard(
      label: left < 0 ? 'Over budget' : 'Budget left',
      icon: Icons.savings_outlined,
      value: formatPaise(left.abs()),
      color: left < 0 ? scheme.error : scheme.onSurface,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  final String label;
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Expanded makes the two cards in a Row share the width equally.
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 6),
              // FittedBox shrinks big amounts so they never overflow the card.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
