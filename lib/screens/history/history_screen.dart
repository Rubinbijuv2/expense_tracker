import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/history_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/placeholder_body.dart';
import '../../widgets/transaction_tile.dart';
import '../add_edit/add_edit_screen.dart';
import 'active_filter_chips.dart';
import 'filter_sheet.dart';

/// Transactions grouped by date, with a search bar (note/merchant), a filter
/// sheet, removable filter chips and the total of the filtered list.
/// Tap a row to edit; swipe left to delete (with Undo).
///
/// A StatefulWidget because it owns the search box's TextEditingController.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    // Start with the provider's text, so it survives switching tabs.
    _searchCtrl =
        TextEditingController(text: context.read<HistoryProvider>().filter.query);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFilters(HistoryProvider history) async {
    final result = await FilterSheet.show(
      context,
      initial: history.filter,
      categoriesFor: history.categoriesFor,
    );
    if (result != null) history.applyFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    // `watch` rebuilds this screen whenever the provider calls notifyListeners().
    final history = context.watch<HistoryProvider>();
    final count = history.filter.activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _openFilters(history),
            // Badge: the small number bubble on the icon.
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_history', // must differ from Home's + button
        tooltip: 'Add transaction',
        onPressed: () => AddEditScreen.open(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _searchBar(history),
          ActiveFilterChips(
            filter: history.filter,
            categoryById: history.categoryById,
            onChanged: history.applyFilter,
          ),
          if (!history.isLoading &&
              history.error == null &&
              !history.hasNoTransactions)
            FilterTotalsBar(
              count: history.results.length,
              spentPaise: history.spentPaise,
              incomePaise: history.incomePaise,
            ),
          Expanded(child: _buildList(context, history)),
        ],
      ),
    );
  }

  Widget _searchBar(HistoryProvider history) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      // ValueListenableBuilder rebuilds only this part when the text changes,
      // to show or hide the clear (✕) button.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (context, value, _) => TextField(
          controller: _searchCtrl,
          onChanged: history.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search note or merchant',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      history.setQuery('');
                    },
                  ),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, HistoryProvider history) {
    if (history.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.error != null) {
      return const PlaceholderBody(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load your transactions. Restart the app.',
      );
    }
    if (history.hasNoTransactions) {
      return const PlaceholderBody(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        message: 'Tap + to add your first expense or income.',
      );
    }
    final groups = history.groupedByDay;
    if (groups.isEmpty) return _noMatches(history);

    final txnProvider = context.read<TransactionProvider>();
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
          onDismissed: (_) => deleteWithUndo(context, txnProvider, t),
          child: TransactionTile(
            txn: t,
            category: history.categoryById(t.categoryId),
            onTap: () => AddEditScreen.open(context, txn: t),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // room for the + button
      // Scrolling the list hides the keyboard.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  Widget _noMatches(HistoryProvider history) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlaceholderBody(
            icon: Icons.search_off,
            title: 'No matching transactions',
            message: 'Try other words or remove some filters.',
          ),
          if (!history.filter.isEmpty)
            FilledButton.tonal(
              onPressed: () {
                _searchCtrl.clear();
                history.clearAll();
              },
              child: const Text('Clear search and filters'),
            ),
        ],
      ),
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
