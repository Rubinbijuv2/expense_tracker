import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/own_account.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/own_accounts_provider.dart';
import '../../utils/validators.dart';

/// Settings → My accounts: the last 4 digits of your own bank accounts and
/// cards. Money moved between two of them is a "self transfer": it is shown
/// greyed and never counted in spending or income.
class MyAccountsScreen extends StatelessWidget {
  const MyAccountsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MyAccountsScreen()));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnAccountsProvider>();
    final accounts = provider.accounts;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add the last 4 digits of each of your own bank accounts and '
              'cards. When an SMS shows money going between two of them (or '
              'says "self"), it is marked Self transfer and left out of all '
              'totals and budgets.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No accounts added yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final a in accounts)
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text('•••• ${a.last4}'),
              subtitle: a.label == null ? null : Text(a.label!),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: () => _remove(context, a),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final provider = context.read<OwnAccountsProvider>();
    final detected = context.read<DetectedSmsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
    if (result == null) return;
    final added = await provider.add(result.$1, result.$2);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added •••• ${result.$1}'
              : '•••• ${result.$1} is already in the list',
        ),
      ),
    );
    // Pending cards may now be self transfers (or stop being one).
    if (added) await detected.recheckPending();
  }

  Future<void> _remove(BuildContext context, OwnAccount a) async {
    final provider = context.read<OwnAccountsProvider>();
    final detected = context.read<DetectedSmsProvider>();
    await provider.remove(a);
    await detected.recheckPending();
  }
}

/// Asks for the 4 digits and an optional name. Returns (last4, label).
class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _digits = TextEditingController();
  final _label = TextEditingController();

  @override
  void dispose() {
    _digits.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (_digits.text.trim(), _label.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add your account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _digits,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              // Only digits can be typed.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Last 4 digits',
                hintText: '1234',
              ),
              validator: validateLast4,
            ),
            TextFormField(
              controller: _label,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'SBI savings',
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
