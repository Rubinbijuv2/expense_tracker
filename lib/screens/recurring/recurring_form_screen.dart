import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_payment.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../add_edit/category_grid.dart';
import '../add_edit/form_parts.dart';
import '../add_edit/payment_mode_chips.dart';
import 'form_fields.dart';
import 'type_fields.dart';

/// Add a repeat payment, or edit [existing]. Only the fields that belong to
/// the chosen type are shown. [prefill] starts a NEW one with some fields
/// filled in (from a "Make it a repeat payment?" suggestion).
class RecurringFormScreen extends StatefulWidget {
  const RecurringFormScreen({super.key, this.existing, this.prefill});

  final RecurringPayment? existing;
  final RecurringPayment? prefill;

  static Future<void> open(
    BuildContext context, {
    RecurringPayment? item,
    RecurringPayment? prefill,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RecurringFormScreen(existing: item, prefill: prefill),
    ),
  );

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _total = TextEditingController();
  final _organiser = TextEditingController();
  final _phone = TextEditingController();
  final _keyword = TextEditingController();
  final _notes = TextEditingController();

  late String _type;
  late String _frequency;
  late int _dueDay;
  late DateTime _start;
  DateTime? _end;
  int? _categoryId;
  late String _mode;
  late int _remind;
  late bool _active;
  bool _dueDayTouched = false;
  String? _categoryError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _monthlyOnly => _type == 'emi' || _type == 'chitti';

  @override
  void initState() {
    super.initState();
    final p = widget.existing ?? widget.prefill;
    final now = DateTime.now();
    _type = p?.type ?? 'bill';
    _frequency = p?.frequency ?? 'monthly';
    _start = p?.startDate ?? DateTime(now.year, now.month, now.day);
    _dueDay = p?.dueDay ?? _start.day;
    _end = p?.endDate;
    _categoryId = p?.categoryId;
    _mode = p?.paymentMode ?? AppConstants.defaultPaymentMode;
    _remind = p?.remindDaysBefore ?? 1;
    _active = p?.active ?? true;
    _dueDayTouched = p != null;
    if (p != null) {
      _name.text = p.name;
      _amount.text = paiseToInput(p.amountPaise);
      _total.text = p.totalInstallments?.toString() ?? '';
      _organiser.text = p.organiserName ?? '';
      _phone.text = p.organiserPhone ?? '';
      _keyword.text = p.matchKeyword ?? '';
      _notes.text = p.notes ?? '';
    }
    // Pick the type's default category once categories are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _categoryId == null) setState(() => _setDefaultCategory());
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _amount,
      _total,
      _organiser,
      _phone,
      _keyword,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _defaultCategoryId(String type) {
    final wanted = RecurringPayment.defaultCategoryName(type).toLowerCase();
    for (final c in context.read<TransactionProvider>().categoriesFor(
      'expense',
    )) {
      if (c.name.toLowerCase() == wanted) return c.id;
    }
    return null;
  }

  void _setDefaultCategory() => _categoryId = _defaultCategoryId(_type);

  void _changeType(String type) {
    setState(() {
      // Only replace the category if it was still the old type's default.
      final wasDefault =
          _categoryId == null || _categoryId == _defaultCategoryId(_type);
      _type = type;
      if (wasDefault) _setDefaultCategory();
      if (_monthlyOnly && _frequency != 'monthly') _changeFrequency('monthly');
    });
  }

  void _changeFrequency(String f) {
    _frequency = f;
    _dueDay = f == 'weekly' ? _start.weekday : _start.day;
  }

  void _changeStart(DateTime d) {
    setState(() {
      _start = d;
      // Yearly items are due on the start date; others follow it until the
      // user picks a due day themselves.
      if (_frequency == 'yearly' || !_dueDayTouched) {
        _dueDay = _frequency == 'weekly' ? d.weekday : d.day;
      }
    });
  }

  Future<void> _save() async {
    final ok = _formKey.currentState!.validate();
    setState(() => _categoryError = validateCategory(_categoryId));
    if (!ok || _categoryError != null) return;
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after the start date')),
      );
      return;
    }

    final old = widget.existing;
    final chitti = _type == 'chitti';
    final p = RecurringPayment(
      id: old?.id,
      name: _name.text.trim(),
      type: _type,
      amountPaise: parseToPaise(_amount.text)!,
      categoryId: _categoryId!,
      frequency: _monthlyOnly ? 'monthly' : _frequency,
      dueDay: _dueDay,
      startDate: _start,
      endDate: _monthlyOnly ? null : _end,
      totalInstallments: _monthlyOnly ? int.parse(_total.text.trim()) : null,
      remindDaysBefore: _remind,
      paymentMode: _mode,
      matchKeyword: textOrNull(_keyword),
      organiserName: chitti ? textOrNull(_organiser) : null,
      organiserPhone: chitti ? textOrNull(_phone)?.replaceAll(' ', '') : null,
      chittiReceivedPaise: chitti ? old?.chittiReceivedPaise : null,
      chittiReceivedDate: chitti ? old?.chittiReceivedDate : null,
      notes: textOrNull(_notes),
      active: _active,
      createdAt: old?.createdAt,
    );

    setState(() => _saving = true);
    try {
      await context.read<RecurringProvider>().save(p);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txns = context.watch<TransactionProvider>();
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit repeat payment' : 'Add repeat payment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TypeSelector(selected: _type, onSelected: _changeType),
            gap,
            NameField(controller: _name, type: _type),
            const SizedBox(height: 8),
            AmountField(
              controller: _amount,
              label: _type == 'chitti' ? 'Usual monthly amount' : 'Amount',
              helperText: _type == 'chitti'
                  ? 'You can change it each month when paying'
                  : null,
            ),
            ExtraTypeFields(
              type: _type,
              total: _total,
              organiser: _organiser,
              phone: _phone,
            ),
            gap,
            ScheduleFields(
              showFrequency: !_monthlyOnly,
              showEndDate: !_monthlyOnly,
              frequency: _monthlyOnly ? 'monthly' : _frequency,
              dueDay: _dueDay,
              startDate: _start,
              endDate: _end,
              onFrequency: (f) => setState(() => _changeFrequency(f)),
              onDueDay: (d) => setState(() {
                _dueDay = d;
                _dueDayTouched = true;
              }),
              onStartDate: _changeStart,
              onEndDate: (d) => setState(() => _end = d),
            ),
            gap,
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryGrid(
              categories: txns.categoriesFor('expense'),
              selectedId: _categoryId,
              onSelected: (id) => setState(() {
                _categoryId = id;
                _categoryError = null;
              }),
            ),
            CategoryErrorText(error: _categoryError),
            gap,
            Text('Payment mode', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            PaymentModeChips(
              selected: _mode,
              onSelected: (m) => setState(() => _mode = m),
            ),
            ReminderFields(
              remindDays: _remind,
              onRemindDays: (v) => setState(() => _remind = v),
              keyword: _keyword,
              notes: _notes,
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Turn off to pause it without deleting'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            gap,
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
