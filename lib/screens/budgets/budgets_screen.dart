import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/category_model.dart';
import '../../providers/budget_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/category_icons.dart';
import '../../utils/formatters.dart';
import '../../widgets/budget_progress.dart';
import '../home/month_switcher.dart';
import 'budget_limit_dialog.dart';

/// Overall monthly budget + optional per-category limits for one month.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  /// Opens the screen on [month] (the month Home is showing).
  static Future<void> open(BuildContext context, DateTime month) {
    context.read<BudgetProvider>().showMonth(month);
    return Navigator.push(
        context, MaterialPageRoute(builder: (_) => const BudgetsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BudgetProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        // A thin progress line under the app bar while the month loads.
        bottom: bp.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MonthSwitcher(
            month: bp.month,
            onPrevious: bp.previousMonth,
            onNext: bp.canGoNext ? bp.nextMonth : null,
          ),
          if (bp.canCopyFromEarlier)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_copy),
                label: const Text("Copy last month's budgets"),
                onPressed: () => _copy(context, bp),
              ),
            ),
          _BudgetCard(
            title: 'Overall monthly budget',
            icon: Icons.savings_outlined,
            color: Theme.of(context).colorScheme.primary,
            budget: bp.overall,
            spentPaise: bp.spentTotal,
            big: true,
            onTap: () => _edit(context, bp, null, 'Overall monthly budget'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Category limits (optional)',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final CategoryModel c in bp.expenseCategories)
            _BudgetCard(
              title: c.name,
              icon: iconFor(c.icon),
              color: Color(c.color),
              budget: bp.budgetFor(c.id!),
              spentPaise: bp.spentFor(c.id!),
              onTap: () => _edit(context, bp, c.id, '${c.name} limit'),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, BudgetProvider bp, int? categoryId,
      String title) async {
    final current = categoryId == null ? bp.overall : bp.budgetFor(categoryId);
    final choice = await BudgetLimitDialog.show(context,
        title: title, currentPaise: current?.limitPaise);
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (choice) {
        case SetLimit(:final paise):
          await bp.setLimit(categoryId, paise);
          // Alerts need notification permission on Android 13+.
          await NotificationService.instance.requestPermission();
        case RemoveLimit():
          await bp.removeLimit(categoryId);
      }
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the budget')));
    }
  }

  Future<void> _copy(BuildContext context, BudgetProvider bp) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await bp.copyFromEarlier();
      messenger.showSnackBar(SnackBar(
          content: Text('Copied $n budget${n == 1 ? '' : 's'}')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not copy budgets')));
    }
  }
}

/// One budget row: icon, name, "₹X of ₹Y", percentage and coloured bar.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.budget,
    required this.spentPaise,
    required this.onTap,
    this.big = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Budget? budget;
  final int spentPaise;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = budget;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      color: big ? theme.colorScheme.surfaceContainerHigh : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // InkWell gives the ripple effect when the card is tapped.
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(big ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: big
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyLarge),
                ),
                if (b == null)
                  Text('Set limit',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary))
                else
                  Text('${budgetPercent(spentPaise, b.limitPaise)}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: budgetColor(context,
                              budgetLevel(spentPaise, b.limitPaise)),
                          fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              if (b == null)
                Text('No limit · ${formatPaise(spentPaise)} spent',
                    style: muted)
              else ...[
                BudgetProgressBar(
                    spentPaise: spentPaise, limitPaise: b.limitPaise),
                const SizedBox(height: 6),
                Text(_detail(spentPaise, b.limitPaise), style: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _detail(int spent, int limit) {
    final left = limit - spent;
    final head = '${formatPaise(spent)} of ${formatPaise(limit)}';
    return left >= 0
        ? '$head · ${formatPaise(left)} left'
        : '$head · ${formatPaise(-left)} over';
  }
}
