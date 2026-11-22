import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../utils/validators.dart';

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

/// "₹ Amount" box with a number keyboard. Used by the Add/Edit form and
/// the repeat payment form.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.helperText,
    this.autofocus = false,
    this.style,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool autofocus;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      // Number keyboard with a decimal point.
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(16),
      ],
      style: style,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixText: '₹ ',
        border: const OutlineInputBorder(),
      ),
      validator: validateAmount,
    );
  }
}

/// Red "Pick a category" line under a category grid; nothing when [error]
/// is null.
class CategoryErrorText extends StatelessWidget {
  const CategoryErrorText({super.key, required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        error!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// "Delete transaction?" dialog. True when the user tapped Delete.
Future<bool> confirmDeleteTransaction(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete transaction?'),
      content: const Text('You can undo this for a few seconds.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
