import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/recurring_payment.dart';
import 'recurring_tile.dart';

/// Chips for Bill / Subscription, EMI / Loan, Chitti and Class / Fee.
class TypeSelector extends StatelessWidget {
  const TypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _icons = {
    'bill': Icons.receipt_long,
    'emi': Icons.credit_score,
    'chitti': Icons.groups,
    'fee': Icons.menu_book,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final t in RecurringPayment.types)
          ChoiceChip(
            avatar: Icon(_icons[t], size: 18),
            label: Text(RecurringPayment.typeLabel(t)),
            selected: selected == t,
            showCheckmark: false,
            onSelected: (_) => onSelected(t),
          ),
      ],
    );
  }
}

/// How often and when: frequency, due day, start date and optional end date.
///
/// EMI and chitti are always monthly, so [showFrequency] is false for them.
/// Bills and fees can have an end date ([showEndDate]).
class ScheduleFields extends StatelessWidget {
  const ScheduleFields({
    super.key,
    required this.showFrequency,
    required this.showEndDate,
    required this.frequency,
    required this.dueDay,
    required this.startDate,
    required this.endDate,
    required this.onFrequency,
    required this.onDueDay,
    required this.onStartDate,
    required this.onEndDate,
  });

  final bool showFrequency;
  final bool showEndDate;
  final String frequency;
  final int dueDay;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<String> onFrequency;
  final ValueChanged<int> onDueDay;
  final ValueChanged<DateTime> onStartDate;
  final ValueChanged<DateTime?> onEndDate;

  static final _fmt = DateFormat('d MMM yyyy');

  Future<DateTime?> _pick(BuildContext context, DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showFrequency) ...[
          Text('How often', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'yearly', label: Text('Yearly')),
            ],
            selected: {frequency},
            onSelectionChanged: (s) => onFrequency(s.first),
          ),
          const SizedBox(height: 12),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(
            frequency == 'yearly' ? 'Due date (every year)' : 'Start date',
          ),
          subtitle: Text(_fmt.format(startDate)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final d = await _pick(context, startDate);
            if (d != null) onStartDate(d);
          },
        ),
        if (frequency == 'monthly')
          DropdownButtonFormField<int>(
            // The key rebuilds the field when dueDay changes from outside
            // (e.g. a new start date), because initialValue is read only once.
            key: ValueKey(dueDay),
            initialValue: dueDay,
            decoration: const InputDecoration(
              labelText: 'Due day of the month',
              helperText: '29–31 move to the last day in shorter months',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(value: d, child: Text(ordinal(d))),
            ],
            onChanged: (v) => onDueDay(v ?? dueDay),
          ),
        if (frequency == 'weekly') ...[
          Text('Due every', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                ChoiceChip(
                  label: Text(weekdayNames[d - 1].substring(0, 3)),
                  selected: dueDay == d,
                  onSelected: (_) => onDueDay(d),
                ),
            ],
          ),
        ],
        if (showEndDate)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: const Text('End date (optional)'),
            subtitle: Text(
              endDate == null ? 'No end date' : _fmt.format(endDate!),
            ),
            trailing: endDate == null
                ? const Icon(Icons.edit_calendar_outlined)
                : IconButton(
                    tooltip: 'Remove end date',
                    icon: const Icon(Icons.close),
                    onPressed: () => onEndDate(null),
                  ),
            onTap: () async {
              final d = await _pick(
                context,
                endDate ?? startDate.add(const Duration(days: 365)),
              );
              if (d != null) onEndDate(d);
            },
          ),
      ],
    );
  }
}
