import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../utils/validators.dart';

/// What the user chose in [BudgetLimitDialog].
sealed class LimitChoice {
  const LimitChoice();
}

class SetLimit extends LimitChoice {
  const SetLimit(this.paise);
  final int paise;
}

class RemoveLimit extends LimitChoice {
  const RemoveLimit();
}

/// A small dialog to type a budget limit in rupees.
/// Returns [SetLimit], [RemoveLimit], or null if cancelled.
class BudgetLimitDialog extends StatefulWidget {
  const BudgetLimitDialog({super.key, required this.title, this.currentPaise});

  final String title;

  /// The current limit, or null when none is set (then "Remove" is hidden).
  final int? currentPaise;

  /// `showDialog` puts the dialog on top of the screen and waits for
  /// `Navigator.pop(value)`, which becomes the returned value.
  static Future<LimitChoice?> show(BuildContext context,
          {required String title, int? currentPaise}) =>
      showDialog<LimitChoice>(
        context: context,
        builder: (_) =>
            BudgetLimitDialog(title: title, currentPaise: currentPaise),
      );

  @override
  State<BudgetLimitDialog> createState() => _BudgetLimitDialogState();
}

class _BudgetLimitDialogState extends State<BudgetLimitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentPaise == null ? '' : paiseToInput(widget.currentPaise!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, SetLimit(parseToPaise(_controller.text)!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly limit',
            prefixText: '₹ ',
          ),
          validator: validateAmount,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        if (widget.currentPaise != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const RemoveLimit()),
            child: Text('Remove limit',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
