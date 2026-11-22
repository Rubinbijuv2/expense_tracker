import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/category_total.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';

/// Donut chart of spending per category, with a legend underneath.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.totals});

  /// Biggest first, as DashboardSummary gives them.
  final List<CategoryTotal> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grandTotal = totals.fold<int>(0, (sum, t) => sum + t.totalPaise);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending by category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (grandTotal == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No spending this month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          for (final t in totals)
                            PieChartSectionData(
                              value: t.totalPaise.toDouble(),
                              color: Color(t.color),
                              radius: 36,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    // Total in the hole of the donut.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total', style: theme.textTheme.labelSmall),
                        Text(
                          formatPaise(grandTotal),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final t in totals) _LegendRow(total: t, of: grandTotal),
            ],
          ],
        ),
      ),
    );
  }
}

/// "● Food ...... ₹1,200.00  40%"
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.total, required this.of});

  final CategoryTotal total;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(total.color);
    final percent = (total.totalPaise * 100 / of).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(iconFor(total.icon), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(total.name, style: theme.textTheme.bodyMedium)),
          Text(
            formatPaise(total.totalPaise),
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
