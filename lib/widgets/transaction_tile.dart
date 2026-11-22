import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/category_icons.dart';
import '../utils/formatters.dart';

/// One transaction row: category icon, name, note/merchant, mode, time, amount.
/// A self transfer is drawn grey with its amount struck through.
/// An expense with linked refunds shows "Refunded ₹X" under its amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txn,
    required this.category,
    this.onTap,
    this.refundedPaise = 0,
  });

  final TransactionModel txn;
  final CategoryModel? category; // null if the category was not found
  final VoidCallback? onTap;
  final int refundedPaise; // total of refunds linked to this expense

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(category?.color ?? 0xFF757575);
    final self = txn.isSelfTransfer; // shown greyed, never counted
    final details = [
      if (self) 'Self transfer',
      if ((txn.merchant ?? '').isNotEmpty) txn.merchant!,
      if ((txn.note ?? '').isNotEmpty) txn.note!,
      txn.paymentMode,
      DateFormat('h:mm a').format(txn.dateTime),
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: self ? 0.06 : 0.15),
        child: Icon(
          self ? Icons.swap_horiz : iconFor(category?.icon ?? ''),
          color: self ? scheme.outline : color,
        ),
      ),
      title: Text(category?.name ?? 'Unknown'),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${txn.isExpense ? '−' : '+'}${formatPaise(txn.amountPaise)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: self
                  ? scheme.outline
                  : (txn.isExpense ? scheme.error : Colors.green.shade600),
              fontWeight: FontWeight.w600,
              decoration: self ? TextDecoration.lineThrough : null,
            ),
          ),
          if (txn.isExpense && refundedPaise > 0)
            Text(
              'Refunded ${formatPaise(refundedPaise)}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Colors.green.shade600),
            ),
        ],
      ),
    );
  }
}

/// Deletes [txn] and shows a snackbar with an "Undo" button.
/// Used by swipe-to-delete in History and the Delete button on the Edit screen.
Future<void> deleteWithUndo(
  BuildContext context,
  TransactionProvider provider,
  TransactionModel txn,
) async {
  // Grab the messenger before any `await`, while `context` is surely valid.
  final messenger = ScaffoldMessenger.of(context);
  try {
    await provider.delete(txn);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not delete. Please try again.')),
    );
    return;
  }
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Deleted ${formatPaise(txn.amountPaise)}'),
      // Snackbars with a button stay forever unless persist is false.
      persist: false,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => provider.restore(txn),
      ),
    ),
  );
}
