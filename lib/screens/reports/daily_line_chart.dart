import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/formatters.dart';

/// Line of spending per day for one month (x = day of month).
class DailyLineChart extends StatelessWidget {
  const DailyLineChart({
    super.key,
    required this.month,
    required this.dailyPaise,
    required this.daysToShow,
  });

  final DateTime month;

  /// Index 0 = day 1; length = days in the month.
  final List<int> dailyPaise;

  /// For the current month only days so far are drawn (no fake zeros
  /// for days that haven't happened yet).
  final int daysToShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = dailyPaise.length;
    final shown = daysToShow.clamp(0, days);
    final maxPaise =
        dailyPaise.fold<int>(0, (m, p) => p > m ? p : m);
    final maxY = maxPaise == 0 ? 1.0 : maxPaise * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily spending', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (maxPaise == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No spending this month',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: 1,
                    maxX: days.toDouble(),
                    minY: 0,
                    maxY: maxY,
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
                          showTitles: true,
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
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final day = value.toInt();
                            // Label day 1, every 5th day, and the last day.
                            final show = day == 1 ||
                                (day % 5 == 0 && days - day >= 3) ||
                                day == days;
                            if (!show) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text('$day',
                                  style: theme.textTheme.labelSmall),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${DateFormat('d MMM').format(DateTime(month.year, month.month, s.x.toInt()))}\n'
                              '${formatPaise(dailyPaise[s.x.toInt() - 1])}',
                              TextStyle(
                                  color: scheme.onInverseSurface, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var d = 1; d <= shown; d++)
                            FlSpot(d.toDouble(), dailyPaise[d - 1].toDouble()),
                        ],
                        color: scheme.primary,
                        barWidth: 2.5,
                        isCurved: false,
                        dotData: FlDotData(
                          // Dots only where money was spent.
                          checkToShowDot: (spot, _) => spot.y > 0,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                  radius: 3,
                                  color: scheme.primary,
                                  strokeWidth: 0),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
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
