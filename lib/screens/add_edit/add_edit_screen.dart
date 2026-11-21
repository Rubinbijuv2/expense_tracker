import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/detected_sms.dart';
import '../../models/transaction_model.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/mark_paid_prompt.dart';
import '../../widgets/transaction_tile.dart';
import 'category_grid.dart';
import 'payment_mode_chips.dart';

/// Add a new transaction, edit [existing], or review a detected SMS
/// ([fromSms]) before saving it.
class AddEditScreen extends StatefulWidget {
  const AddEditScreen({super.key, this.existing, this.fromSms});

  final TransactionModel? existing;
  final DetectedSms? fromSms;

  /// Opens this screen. Used by the + buttons and by tapping a row.
  static Future<void> open(BuildContext context, {TransactionModel? txn}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditScreen(existing: txn)),
    );
  }

  /// "Edit" on a detected SMS: the form starts filled with the SMS details.
  static Future<void> openFromSms(BuildContext context, DetectedSms sms) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditScreen(fromSms: sms)),
    );
  }

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  // The form key lets us run every field's validator at once on Save.
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late String _type;
  int? _categoryId;
  late String _paymentMode;
  late DateTime _dateTime;
  String? _categoryError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _type = t?.type ?? 'expense';
    _categoryId = t?.categoryId;
    _paymentMode = t?.paymentMode ?? AppConstants.defaultPaymentMode;
    _dateTime = t?.dateTime ?? DateTime.now();
    if (t != null) {
      _amountCtrl.text = paiseToInput(t.amountPaise);
      _noteCtrl.text = t.note ?? '';
    }
    final sms = widget.fromSms;
    if (sms != null) {
      _type = sms.type;
      _categoryId = sms.guessedCategoryId;
      _paymentMode = sms.paymentMode ?? AppConstants.defaultPaymentMode;
      _dateTime = sms.receivedAt;
      _amountCtrl.text = paiseToInput(sms.amountPaise);
    }
  }

  @override
  void dispose() {
    // Controllers hold resources; free them when the screen closes.
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _changeType(String type) {
    setState(() {
      _type = type;
      // The old category belongs to the other type, so clear it.
      _categoryId = null;
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(_dateTime);
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _categoryError = validateCategory(_categoryId));
    if (!formOk || _categoryError != null) return;

    final provider = context.read<TransactionProvider>();
    final smsProvider = context.read<DetectedSmsProvider>();
    final old = widget.existing;
    final sms = widget.fromSms;
    final note = _noteCtrl.text.trim();
    final txn = TransactionModel(
      id: old?.id,
      amountPaise: parseToPaise(_amountCtrl.text)!,
      type: _type,
      categoryId: _categoryId!,
      paymentMode: _paymentMode,
      dateTime: _dateTime,
      note: note.isEmpty ? null : note,
      merchant: old?.merchant ?? sms?.merchant,
      source: sms != null ? 'sms' : (old?.source ?? 'manual'),
      smsId: old?.smsId ?? sms?.id,
      createdAt: old?.createdAt,
      // Keep the links an edit can't change on this screen.
      recurringId: old?.recurringId,
      refundOfId: old?.refundOfId,
      isSelfTransfer: old?.isSelfTransfer ?? sms?.isSelfTransfer ?? false,
    );

    setState(() => _saving = true);
    try {
      TransactionModel saved = txn;
      if (sms != null) {
        // Also marks the SMS as saved and learns a merchant rule if the
        // category was changed.
        saved = await smsProvider.saveEdited(sms, txn);
      } else if (_isEdit) {
        await provider.update(txn);
      } else {
        saved = txn.copyWith(id: await provider.add(txn));
      }
      // A new expense that matches a due repeat payment: ask to mark it.
      if (!_isEdit && mounted) await offerMarkPaid(context, saved);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('You can undo this for a few seconds.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<TransactionProvider>();
    // Start the delete (it shows the Undo snackbar), then close this screen.
    deleteWithUndo(context, provider, widget.existing!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fromSms != null
            ? 'Add from SMS: ${widget.fromSms!.merchant ?? 'Unknown'}'
            : (_isEdit ? 'Edit transaction' : 'Add transaction')),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward)),
                ButtonSegment(
                    value: 'income',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _changeType(s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              autofocus: !_isEdit,
              // Number keyboard with a decimal point.
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(16),
              ],
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: validateAmount,
            ),
            const SizedBox(height: 20),
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryGrid(
              categories: provider.categoriesFor(_type),
              selectedId: _categoryId,
              onSelected: (id) => setState(() {
                _categoryId = id;
                _categoryError = null;
              }),
            ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(_categoryError!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 20),
            Text('Payment mode', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            PaymentModeChips(
              selected: _paymentMode,
              onSelected: (mode) => setState(() => _paymentMode = mode),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat('EEE, d MMM yyyy · h:mm a')
                  .format(_dateTime)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Save'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
