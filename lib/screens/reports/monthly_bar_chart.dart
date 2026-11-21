import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/report_summary.dart';
import '../../utils/formatters.dart';

/// Bars of total spending for the last 6 months. The last bar (the month
/// being viewed) is drawn in the strong theme colour, the others lighter.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.months});

  /// Oldest first, as ReportSummary.lastSixMonths gives them.
  final List<MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxPaise =
        months.fold<int>(0, (m, t) => t.spentPaise > m ? t.spentPaise : m);
    // 20% headroom above the tallest bar; 1 so an all-zero chart still draws.
    final maxY = maxPaise == 0 ? 1.0 : maxPaise * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending — last 6 months', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              // Bar values are in paise (as doubles) only for drawing.
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                        strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: maxPaise > 0,
                        reservedSize: 48,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(formatPaiseCompact(value.round()),
                              style: theme.textTheme.labelSmall),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(DateFormat('MMM').format(months[i].month),
                                style: theme.textTheme.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${DateFormat('MMM yyyy').format(months[group.x].month)}\n'
                        '${formatPaise(months[group.x].spentPaise)}',
                        TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: months[i].spentPaise.toDouble(),
                          width: 22,
                          color: i == months.length - 1
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.4),
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
