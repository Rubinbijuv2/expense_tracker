import 'package:flutter/material.dart';

import '../../models/detected_sms.dart';

/// The small coloured label on a detected SMS card (PLAN.md rule 4):
/// **Bank** (high confidence), **Receipt** (medium), **Check this** (low),
/// **Self transfer**, or **App · Google Pay** for a payment app
/// notification (PLAN.md 7.4).
class KindLabel extends StatelessWidget {
  const KindLabel({super.key, required this.sms});

  final DetectedSms sms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (text, icon, color) = sms.isSelfTransfer
        ? ('Self transfer', Icons.swap_horiz, scheme.outline)
        : sms.isNotification
        ? (sms.kindLabel, Icons.phone_android, Colors.purple.shade700)
        : switch (sms.kind) {
            'bank' => ('Bank', Icons.verified_outlined, Colors.green.shade700),
            'receipt' => (
              'Receipt',
              Icons.receipt_outlined,
              Colors.blue.shade700,
            ),
            _ => ('Check this', Icons.help_outline, Colors.orange.shade800),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
