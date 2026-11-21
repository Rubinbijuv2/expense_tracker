import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/placeholder_body.dart';
import '../../widgets/transaction_tile.dart';
import '../add_edit/add_edit_screen.dart';
import '../budgets/budgets_screen.dart';
import 'budget_bar_card.dart';
import 'category_pie_chart.dart';
import 'detected_sms_strip.dart';
import 'month_switcher.dart';
import 'repeat_suggestion_card.dart';
import 'summary_cards.dart';
import 'upcoming_card.dart';

/// Dashboard: month switcher, totals, budget with forecast, detected SMS
/// strip, Upcoming repeat payments, repeat-payment suggestion, pie chart of
/// spending and the last 5 transactions of the month.
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
    BuildContext context,
    TransactionProvider txns,
    DashboardProvider dash,
  ) {
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
    final recurring = context.watch<RecurringProvider>();
    // Forecast only makes sense for the current month.
    final now = DateTime.now();
    final isThisMonth =
        dash.month.year == now.year && dash.month.month == now.month;
    // RefreshIndicator: pull the list down to reload from the database.
    return RefreshIndicator(
      onRefresh: () async {
        await txns.load();
        await dash.loadBudget();
        await detected.load();
        await recurring.load();
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
            upcomingPaise: isThisMonth ? recurring.dueThisMonthPaise : 0,
            onTap: () => _openBudgets(context, dash),
          ),
          const DetectedSmsStrip(),
          const UpcomingCard(),
          const RepeatSuggestionCard(),
          CategoryPieChart(totals: s.byCategory),
          const _SectionTitle(title: 'Recent transactions'),
          if (s.recent.isEmpty)
            _EmptyRecent(
              message: txns.transactions.isEmpty
                  ? 'No expenses yet — tap + to add one'
                  : 'Nothing added in ${DateFormat('MMMM').format(dash.month)}',
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

/// Shown under "Recent transactions" when the month has none.
class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: muted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
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
