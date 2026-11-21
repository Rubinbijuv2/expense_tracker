import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/recurring_provider.dart';
import '../utils/formatters.dart';

/// Auto-match after saving (PLAN.md 5.3): if the saved expense [txn] looks
/// like a repeat payment that is due, ask "Mark Bike EMI as paid?".
/// Nothing is marked unless the user taps "Mark as paid".
Future<void> offerMarkPaid(BuildContext context, TransactionModel txn) async {
  if (txn.id == null || txn.recurringId != null || txn.isSelfTransfer) return;
  final rec = context.read<RecurringProvider>();
  final match = rec.matchFor(
    type: txn.type,
    amountPaise: txn.amountPaise,
    date: txn.dateTime,
    text: '${txn.merchant ?? ''} ${txn.note ?? ''}',
  );
  if (match == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final p = match.item;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.event_repeat),
      title: Text('Mark ${p.name} as paid?'),
      content: Text(
        'This ${formatPaise(txn.amountPaise)} expense matches ${p.name}, due '
        '${DateFormat('d MMM').format(match.next.dueDate)}. It will be linked '
        'to it, so no second expense is added.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mark as paid'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await rec.linkPaid(p, match.next, txn);
    messenger.showSnackBar(SnackBar(content: Text('${p.name} marked as paid')));
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not link. Please try again.')),
    );
  }
}
