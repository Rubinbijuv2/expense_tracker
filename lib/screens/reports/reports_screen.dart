import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/placeholder_body.dart';
import '../home/month_switcher.dart';
import 'daily_line_chart.dart';
import 'monthly_bar_chart.dart';
import 'top_merchants_card.dart';

/// Reports tab: month picker, 6-month bar chart, daily line chart,
/// average per day, top merchants, and CSV/PDF export.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    Future<String?> Function() run,
  ) async {
    // Grab the messenger before the `await`: `context` may not be safe after it.
    final messenger = ScaffoldMessenger.of(context);
    final error = await run();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportProvider>();
    final s = reports.summary;
    final noData = context.select<TransactionProvider, bool>(
      (t) => !t.isLoading && t.transactions.isEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (reports.isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: reports.canExport
                ? () => _export(context, reports.exportCsv)
                : null,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: reports.canExport
                ? () => _export(context, reports.exportPdf)
                : null,
          ),
        ],
      ),
      body: reports.isLoading
          ? const Center(child: CircularProgressIndicator())
          : noData
          ? const PlaceholderBody(
              icon: Icons.bar_chart_outlined,
              title: 'No data to report yet',
              message:
                  'Add a few expenses and your charts, daily spending '
                  'and top merchants will show up here.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                MonthSwitcher(
                  month: reports.month,
                  onPrevious: reports.previousMonth,
                  onNext: reports.canGoNext ? reports.nextMonth : null,
                ),
                ReportStatsRow(summary: s),
                MonthlyBarChart(months: s.lastSixMonths),
                DailyLineChart(
                  month: s.month,
                  dailyPaise: s.dailySpentPaise,
                  daysToShow: s.daysCounted,
                ),
                TopMerchantsCard(merchants: s.topMerchants),
              ],
            ),
    );
  }
}
