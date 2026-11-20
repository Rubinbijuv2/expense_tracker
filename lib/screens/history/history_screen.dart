import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/placeholder_body.dart';
import '../../widgets/transaction_tile.dart';
import '../add_edit/add_edit_screen.dart';

/// All transactions, grouped by date with daily totals.
/// Tap a row to edit; swipe left to delete (with Undo).
/// Search and filters come in step 8.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` rebuilds this screen whenever the provider calls notifyListeners().
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_history', // must differ from Home's + button
        tooltip: 'Add transaction',
        onPressed: () => AddEditScreen.open(context),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, TransactionProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return const PlaceholderBody(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load your transactions. Restart the app.',
      );
    }
    final groups = provider.groupedByDay;
    if (groups.isEmpty) {
      return const PlaceholderBody(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        message: 'Tap + to add your first expense or income.',
      );
    }

    // Flatten into one list of rows: a header, its transactions, next header…
    final rows = <Widget>[];
    for (final g in groups) {
      rows.add(_DayHeader(group: g));
      for (final t in g.items) {
        rows.add(Dismissible(
          // The key tells Flutter which row was swiped, even after the list changes.
          key: ValueKey('txn_${t.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          onDismissed: (_) => deleteWithUndo(context, provider, t),
          child: TransactionTile(
            txn: t,
            category: provider.categoryById(t.categoryId),
            onTap: () => AddEditScreen.open(context, txn: t),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // room for the + button
      children: rows,
    );
  }
}

/// "Today · −₹1,250.00 · +₹500.00" above each day's transactions.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final DayGroup group;

  String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.labelLarge;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(_label(group.day), style: small)),
          if (group.expensePaise > 0)
            Text('−${formatPaise(group.expensePaise)}',
                style: small?.copyWith(color: theme.colorScheme.error)),
          if (group.expensePaise > 0 && group.incomePaise > 0)
            Text('  ·  ', style: small),
          if (group.incomePaise > 0)
            Text('+${formatPaise(group.incomePaise)}',
                style: small?.copyWith(color: Colors.green.shade600)),
        ],
      ),
    );
  }
}
