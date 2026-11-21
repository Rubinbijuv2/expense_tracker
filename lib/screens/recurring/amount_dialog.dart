import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/recurring_installment.dart';
import '../../models/recurring_payment.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

/// What the user chose in the "Mark as paid" dialog.
typedef PaidChoice = ({int amountPaise, bool addTransaction});

/// "Mark as paid". For chitti the amount box is editable (it can change every
/// month) and starts with the usual amount; for others the amount is fixed.
/// Returns null if cancelled.
Future<PaidChoice?> showMarkPaidDialog(
  BuildContext context,
  RecurringPayment p,
  RecurringInstallment inst,
) {
  return showDialog<PaidChoice>(
    context: context,
    builder: (_) => _MarkPaidDialog(item: p, inst: inst),
  );
}

class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({required this.item, required this.inst});

  final RecurringPayment item;
  final RecurringInstallment inst;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: paiseToInput(widget.item.amountPaise),
  );
  bool _addTxn = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _ok() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<PaidChoice>(context, (
      amountPaise: parseToPaise(_amount.text)!,
      addTransaction: _addTxn,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.item;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Mark ${p.name} as paid'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Due ${DateFormat('d MMM yyyy').format(widget.inst.dueDate)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (p.isChitti)
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount paid this month',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: validateAmount,
              )
            else
              Text(
                formatPaise(p.amountPaise),
                style: theme.textTheme.headlineSmall,
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add as an expense'),
              subtitle: Text(
                _addTxn
                    ? 'Saved today in your transactions'
                    : 'Only marks it paid (already recorded)',
              ),
              value: _addTxn,
              onChanged: (v) => setState(() => _addTxn = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Mark as paid')),
      ],
    );
  }
}

/// What the user entered in "I received the chitti".
typedef ReceivedChoice = ({int amountPaise, DateTime date});

/// "I received the chitti": asks the lump sum and the date. Null if cancelled.
Future<ReceivedChoice?> showChittiReceivedDialog(BuildContext context) {
  return showDialog<ReceivedChoice>(
    context: context,
    builder: (_) => const _ChittiReceivedDialog(),
  );
}

class _ChittiReceivedDialog extends StatefulWidget {
  const _ChittiReceivedDialog();

  @override
  State<_ChittiReceivedDialog> createState() => _ChittiReceivedDialogState();
}

class _ChittiReceivedDialogState extends State<_ChittiReceivedDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, 12));
  }

  void _ok() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<ReceivedChoice>(context, (
      amountPaise: parseToPaise(_amount.text)!,
      date: _date,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('I received the chitti'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The amount is saved as income in "Chitti received".'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount received',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: validateAmount,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('d MMM yyyy').format(_date)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Save')),
      ],
    );
  }
}
