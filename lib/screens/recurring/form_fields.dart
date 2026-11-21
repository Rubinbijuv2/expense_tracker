import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _border = OutlineInputBorder();

/// EMI / chitti: total months. Chitti: organiser name and phone.
/// Shows nothing for bills and fees.
class ExtraTypeFields extends StatelessWidget {
  const ExtraTypeFields({
    super.key,
    required this.type,
    required this.total,
    required this.organiser,
    required this.phone,
  });

  final String type;
  final TextEditingController total;
  final TextEditingController organiser;
  final TextEditingController phone;

  static String? validateTotal(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 1 || n > 600) return 'Enter a number from 1 to 600';
    return null;
  }

  static String? validatePhone(String? v) {
    final t = (v ?? '').replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (!RegExp(r'^\+?\d{10,13}$').hasMatch(t)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (type != 'emi' && type != 'chitti') return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: total,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: type == 'emi'
                ? 'Total installments (months)'
                : 'Total months',
            border: _border,
          ),
          validator: validateTotal,
        ),
        if (type == 'chitti') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: organiser,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Organiser name (optional)',
              border: _border,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Organiser phone (optional)',
              border: _border,
            ),
            validator: validatePhone,
          ),
        ],
      ],
    );
  }
}

/// Remind-days-before, SMS match keyword and notes (common to every type).
class ReminderFields extends StatelessWidget {
  const ReminderFields({
    super.key,
    required this.remindDays,
    required this.onRemindDays,
    required this.keyword,
    required this.notes,
  });

  final int remindDays;
  final ValueChanged<int> onRemindDays;
  final TextEditingController keyword;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue: remindDays,
          decoration: const InputDecoration(
            labelText: 'Remind me',
            border: _border,
          ),
          items: [
            for (var d = 0; d <= 7; d++)
              DropdownMenuItem(
                value: d,
                child: Text(
                  d == 0
                      ? 'On the due day only'
                      : '$d day${d == 1 ? '' : 's'} before',
                ),
              ),
          ],
          onChanged: (v) => onRemindDays(v ?? 1),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: keyword,
          maxLength: 30,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'SMS match keyword (optional)',
            helperText: 'Words from the bank SMS, e.g. HDFC LOAN',
            border: _border,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: notes,
          maxLength: 200,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: _border,
          ),
        ),
      ],
    );
  }
}
