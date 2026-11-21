import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category_model.dart';
import '../../models/transaction_filter.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// Bottom sheet with every History filter. Changes stay inside the sheet
/// until "Apply"; the sheet then returns the new [TransactionFilter].
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.initial,
    required this.categoriesFor,
  });

  final TransactionFilter initial;
  final List<CategoryModel> Function(String? type) categoriesFor;

  /// Opens the sheet; returns the chosen filter, or null if dismissed.
  static Future<TransactionFilter?> show(
    BuildContext context, {
    required TransactionFilter initial,
    required List<CategoryModel> Function(String? type) categoriesFor,
  }) {
    // isScrollControlled lets the sheet be taller than half the screen and
    // move up above the keyboard.
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          FilterSheet(initial: initial, categoriesFor: categoriesFor),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  String? _type;
  DateTimeRange? _range;
  late Set<int> _categoryIds;
  late Set<String> _modes;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _type = f.type;
    if (f.hasDateRange) {
      _range = DateTimeRange(
        start: f.from ?? f.to!,
        end: f.to ?? f.from!,
      );
    }
    _categoryIds = {...f.categoryIds};
    _modes = {...f.paymentModes};
    _minCtrl = TextEditingController(
        text: f.minPaise == null ? '' : paiseToInput(f.minPaise!));
    _maxCtrl = TextEditingController(
        text: f.maxPaise == null ? '' : paiseToInput(f.maxPaise!));
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _setType(String? type) {
    setState(() {
      _type = type;
      // Drop chosen categories that don't belong to the new type.
      final allowed = {for (final c in widget.categoriesFor(type)) c.id};
      _categoryIds.removeWhere((id) => !allowed.contains(id));
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Select date range',
    );
    if (picked != null) setState(() => _range = picked);
  }

  String? _validateAmount(String? text) {
    if (text == null || text.trim().isEmpty) return null; // optional
    if (parseToPaise(text) == null) return 'Enter a valid amount';
    return null;
  }

  String? _validateMax(String? text) {
    final err = _validateAmount(text);
    if (err != null) return err;
    final min = parseToPaise(_minCtrl.text);
    final max = parseToPaise(text);
    if (min != null && max != null && max < min) return 'Must be ≥ min';
    return null;
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    final min = parseToPaise(_minCtrl.text);
    final max = parseToPaise(_maxCtrl.text);
    Navigator.pop(
      context,
      TransactionFilter(
        query: widget.initial.query,
        type: _type,
        from: _range?.start,
        to: _range?.end,
        categoryIds: _categoryIds,
        paymentModes: _modes,
        minPaise: min,
        maxPaise: max,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _range = null;
      _categoryIds = {};
      _modes = {};
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = theme.textTheme.titleSmall;
    final dateFmt = DateFormat('d MMM yyyy');

    return Padding(
      // Push the content above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Filters', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),

            Text('Type', style: title),
            const SizedBox(height: 8),
            // SegmentedButton: a row of joined buttons where one is selected.
            SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: 20),

            Text('Date range', style: title),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_range == null
                        ? 'Any date'
                        : '${dateFmt.format(_range!.start)} – '
                            '${dateFmt.format(_range!.end)}'),
                    onPressed: _pickRange,
                  ),
                ),
                if (_range != null)
                  IconButton(
                    tooltip: 'Clear dates',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _range = null),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Categories', style: title),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in widget.categoriesFor(_type))
                  FilterChip(
                    label: Text(c.name),
                    selected: _categoryIds.contains(c.id),
                    onSelected: (on) => setState(() =>
                        on ? _categoryIds.add(c.id!) : _categoryIds.remove(c.id)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Payment mode', style: title),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in AppConstants.paymentModes)
                  FilterChip(
                    label: Text(m),
                    selected: _modes.contains(m),
                    onSelected: (on) => setState(
                        () => on ? _modes.add(m) : _modes.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Amount (₹)', style: title),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _amountField(_minCtrl, 'Min', _validateAmount)),
                const SizedBox(width: 12),
                Expanded(child: _amountField(_maxCtrl, 'Max', _validateMax)),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAll,
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController ctrl, String label,
      String? Function(String?) validator) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }
}
