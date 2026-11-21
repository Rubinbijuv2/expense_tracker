import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Expense / Income switch at the top of the Add/Edit form.
class TypeToggle extends StatelessWidget {
  const TypeToggle({super.key, required this.type, required this.onChanged});

  final String type; // 'expense' or 'income'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'expense',
          label: Text('Expense'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: 'income',
          label: Text('Income'),
          icon: Icon(Icons.arrow_downward),
        ),
      ],
      selected: {type},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// "Sat, 21 Nov 2026 · 9:05 PM" row; tapping it opens the pickers.
class DateTimeTile extends StatelessWidget {
  const DateTimeTile({super.key, required this.dateTime, required this.onTap});

  final DateTime dateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(dateTime)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}
