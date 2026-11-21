import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/placeholder_body.dart';
import '../../widgets/transaction_tile.dart';
import '../add_edit/add_edit_screen.dart';
import 'category_pie_chart.dart';
import 'month_switcher.dart';
import 'summary_cards.dart';

/// Dashboard: month switcher, totals, detected SMS (placeholder),
/// pie chart of spending and the last 5 transactions of the month.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TransactionProvider>();
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_home', // must differ from History's + button
        tooltip: 'Add transaction',
        onPressed: () => AddEditScreen.open(context),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, txns, dash),
    );
  }

  Widget _buildBody(
      BuildContext context, TransactionProvider txns, DashboardProvider dash) {
    if (txns.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (txns.error != null) {
      return const PlaceholderBody(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load your transactions. Restart the app.',
      );
    }

    final s = dash.summary;
    // RefreshIndicator: pull the list down to reload from the database.
    return RefreshIndicator(
      onRefresh: () async {
        await txns.load();
        await dash.loadBudget();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88), // room for the + button
        children: [
          MonthSwitcher(
            month: dash.month,
            onPrevious: dash.previousMonth,
            onNext: dash.canGoNext ? dash.nextMonth : null,
          ),
          SummaryCards(
            spentPaise: s.spentPaise,
            incomePaise: s.incomePaise,
            balancePaise: s.balancePaise,
            budgetLimitPaise: dash.budget?.limitPaise,
          ),
          const _DetectedSmsPlaceholder(),
          CategoryPieChart(totals: s.byCategory),
          const _SectionTitle(title: 'Recent transactions'),
          if (s.recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No transactions this month')),
            )
          else
            for (final t in s.recent)
              TransactionTile(
                txn: t,
                category: txns.categoryById(t.categoryId),
                onTap: () => AddEditScreen.open(context, txn: t),
              ),
        ],
      ),
    );
  }
}

/// Space for the "Detected SMS" strip, filled in step 6.
class _DetectedSmsPlaceholder extends StatelessWidget {
  const _DetectedSmsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: ListTile(
        leading: Icon(Icons.sms_outlined, color: theme.colorScheme.secondary),
        title: const Text('Detected SMS'),
        subtitle: const Text('Bank SMS suggestions will appear here.'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
