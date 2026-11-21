import 'package:flutter/material.dart';

/// How full a budget is, which decides the bar colour (PLAN.md module 5).
enum BudgetLevel { ok, warning, over }

/// Pure helper (no Flutter), so it is unit-tested.
/// Below 80% → ok (green), 80–99% → warning (amber), 100%+ → over (red).
/// Integer maths (spent * 100 vs limit * 80) avoids decimal rounding at the edges.
BudgetLevel budgetLevel(int spentPaise, int limitPaise) {
  if (limitPaise <= 0) return BudgetLevel.ok;
  if (spentPaise * 100 >= limitPaise * 100) return BudgetLevel.over;
  if (spentPaise * 100 >= limitPaise * 80) return BudgetLevel.warning;
  return BudgetLevel.ok;
}

/// Whole-number percentage used, e.g. 4500 of 10000 → 45. Can go above 100.
int budgetPercent(int spentPaise, int limitPaise) =>
    limitPaise <= 0 ? 0 : (spentPaise * 100) ~/ limitPaise;

Color budgetColor(BuildContext context, BudgetLevel level) {
  switch (level) {
    case BudgetLevel.over:
      return Theme.of(context).colorScheme.error;
    case BudgetLevel.warning:
      return Colors.amber.shade700;
    case BudgetLevel.ok:
      return Colors.green.shade600;
  }
}

/// A rounded progress bar coloured green → amber → red.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.spentPaise,
    required this.limitPaise,
    this.height = 8,
  });

  final int spentPaise;
  final int limitPaise;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = budgetColor(context, budgetLevel(spentPaise, limitPaise));
    final used = limitPaise <= 0 ? 0.0 : spentPaise / limitPaise;
    return LinearProgressIndicator(
      value: used.clamp(0.0, 1.0),
      color: color,
      backgroundColor: color.withValues(alpha: 0.2),
      minHeight: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }
}
