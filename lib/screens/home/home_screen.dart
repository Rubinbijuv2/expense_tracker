import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/placeholder_body.dart';
import '../../widgets/transaction_tile.dart';
import '../add_edit/add_edit_screen.dart';
import '../budgets/budgets_screen.dart';
import 'budget_bar_card.dart';
import 'category_pie_chart.dart';
import 'detected_sms_strip.dart';
import 'month_switcher.dart';
import 'summary_cards.dart';

/// Dashboard: month switcher, totals, detected SMS strip,
/// pie chart of spending and the last 5 transactions of the month.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TransactionProvider>();
    final dash = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Budgets',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => _openBudgets(context, dash),
          ),
        ],
      ),
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
    final detected = context.read<DetectedSmsProvider>();
    // RefreshIndicator: pull the list down to reload from the database.
    return RefreshIndicator(
      onRefresh: () async {
        await txns.load();
        await dash.loadBudget();
        await detected.load();
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
          BudgetBarCard(
            spentPaise: s.spentPaise,
            limitPaise: dash.budget?.limitPaise,
            onTap: () => _openBudgets(context, dash),
          ),
          const DetectedSmsStrip(),
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

/// Opens Budgets on the month Home shows, then reloads Home's budget
/// (it may have been changed there).
Future<void> _openBudgets(BuildContext context, DashboardProvider dash) async {
  await BudgetsScreen.open(context, dash.month);
  await dash.loadBudget();
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
