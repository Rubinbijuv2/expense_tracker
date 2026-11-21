import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/detected_sms_provider.dart';

/// Explains why we need SMS access, then (if the user agrees) shows
/// Android's permission popup. Used on first launch and by the Home banner.
Future<void> askForSmsPermission(BuildContext context) async {
  final provider = context.read<DetectedSmsProvider>();
  final agreed = await showDialog<bool>(
    context: context,
    builder: (ctx) => const SmsPermissionDialog(),
  );
  if (agreed == true) await provider.requestPermission();
}

class SmsPermissionDialog extends StatelessWidget {
  const SmsPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.sms_outlined),
      title: const Text('Detect expenses from SMS?'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense Tracker can read your bank and UPI SMS and suggest '
              'transactions, so you don\'t have to type them.'),
          SizedBox(height: 12),
          _Point(icon: Icons.account_balance, text: 'Only SMS from bank senders '
              '(like AX-HDFCBK) are read. Personal messages are skipped.'),
          _Point(icon: Icons.cloud_off, text: 'Everything stays on this phone. '
              'The app has no internet access.'),
          _Point(icon: Icons.touch_app, text: 'Nothing is added until you tap Save.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
