import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/transaction_filter.dart';
import '../../utils/formatters.dart';

/// A sideways-scrolling row of chips, one per active filter.
/// Tapping a chip's ✕ removes that filter and calls [onChanged].
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filter,
    required this.categoryById,
    required this.onChanged,
  });

  final TransactionFilter filter;
  final CategoryModel? Function(int id) categoryById;
  final ValueChanged<TransactionFilter> onChanged;

  String _dateLabel() {
    final fmt = DateFormat('d MMM yy');
    final from = filter.from, to = filter.to;
    if (from != null && to != null) {
      return from == to
          ? fmt.format(from)
          : '${fmt.format(from)} – ${fmt.format(to)}';
    }
    return from != null
        ? 'From ${fmt.format(from)}'
        : 'Until ${fmt.format(to!)}';
  }

  String _amountLabel() {
    final min = filter.minPaise, max = filter.maxPaise;
    if (min != null && max != null) {
      return '${formatPaise(min)} – ${formatPaise(max)}';
    }
    return min != null ? '≥ ${formatPaise(min)}' : '≤ ${formatPaise(max!)}';
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (filter.type != null)
        _chip(
          filter.type == 'expense' ? 'Expense' : 'Income',
          () => onChanged(filter.copyWith(clearType: true)),
        ),
      if (filter.hasDateRange)
        _chip(_dateLabel(), () => onChanged(filter.copyWith(clearDates: true))),
      // One chip per category and per mode, so each can be removed alone.
      for (final id in filter.categoryIds)
        _chip(
          categoryById(id)?.name ?? 'Unknown',
          () => onChanged(
            filter.copyWith(categoryIds: {...filter.categoryIds}..remove(id)),
          ),
        ),
      for (final mode in filter.paymentModes)
        _chip(
          mode,
          () => onChanged(
            filter.copyWith(
              paymentModes: {...filter.paymentModes}..remove(mode),
            ),
          ),
        ),
      if (filter.hasAmountRange)
        _chip(
          _amountLabel(),
          () => onChanged(filter.copyWith(clearAmounts: true)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => InputChip(
    label: Text(label),
    onDeleted: onRemove,
    deleteButtonTooltipMessage: 'Remove filter',
  );
}

/// "12 results · Spent ₹4,250.00 · Income ₹1,000.00" for the filtered list.
class FilterTotalsBar extends StatelessWidget {
  const FilterTotalsBar({
    super.key,
    required this.count,
    required this.spentPaise,
    required this.incomePaise,
  });

  final int count;
  final int spentPaise;
  final int incomePaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$count ${count == 1 ? 'result' : 'results'}',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'Spent ${formatPaise(spentPaise)}',
            style: style?.copyWith(color: theme.colorScheme.error),
          ),
          Text(
            'Income ${formatPaise(incomePaise)}',
            style: style?.copyWith(color: Colors.green.shade600),
          ),
        ],
      ),
    );
  }
}
