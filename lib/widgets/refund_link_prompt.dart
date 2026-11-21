import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../utils/formatters.dart';

/// The user's choice in [pickRefundExpense]. [expenseId] null = "not linked".
class RefundPick {
  const RefundPick(this.expenseId);
  final int? expenseId;
}

/// After a Refund income is saved (PLAN.md 6.2): "Is this a refund for…?"
/// with recent expenses from the same merchant. Nothing is linked unless the
/// user taps one. Shows nothing if there is no matching expense.
Future<void> offerRefundLink(
  BuildContext context,
  TransactionModel saved,
) async {
  final txns = context.read<TransactionProvider>();
  if (saved.id == null || saved.refundOfId != null || !txns.isRefund(saved)) {
    return;
  }
  if (txns.refundCandidates(saved).isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final pick = await pickRefundExpense(context, saved);
  if (pick?.expenseId == null) return;
  try {
    await txns.linkRefund(saved, pick!.expenseId);
    final e = txns.byId(pick.expenseId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Linked to ${_name(txns, e)} ${formatPaise(e?.amountPaise ?? 0)}',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not link. Please try again.')),
    );
  }
}

/// Dialog listing the expenses [refund] may belong to. Returns null if
/// closed, or a [RefundPick] ([allowUnlink] adds a "Not linked" choice).
Future<RefundPick?> pickRefundExpense(
  BuildContext context,
  TransactionModel refund, {
  bool allowUnlink = false,
}) {
  final txns = context.read<TransactionProvider>();
  final list = txns.refundCandidates(refund);
  final hasMerchant = (refund.merchant ?? '').trim().isNotEmpty;
  return showDialog<RefundPick>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.currency_exchange),
      title: Text(
        'Refund of ${formatPaise(refund.amountPaise)}: for which expense?',
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  hasMerchant
                      ? 'No expense from ${refund.merchant} in the last 60 days.'
                      : 'No expense of this amount or more in the last 60 days.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final e in list)
                    ListTile(
                      leading: Icon(
                        e.id == refund.refundOfId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(
                        '${_name(txns, e)} · ${formatPaise(e.amountPaise)}',
                      ),
                      subtitle: Text(
                        DateFormat('d MMM yyyy').format(e.dateTime),
                      ),
                      onTap: () => Navigator.pop(ctx, RefundPick(e.id)),
                    ),
                ],
              ),
      ),
      actions: [
        if (allowUnlink && refund.refundOfId != null)
          TextButton(
            onPressed: () => Navigator.pop(ctx, const RefundPick(null)),
            child: const Text('Remove link'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(allowUnlink ? 'Cancel' : 'Not now'),
        ),
      ],
    ),
  );
}

/// Edit screen row for a Refund: "Refund of: Flipkart ₹499 · 12 Nov".
/// Tapping it picks another expense or removes the link; the choice is
/// saved with the rest of the form ([onChanged]).
class RefundLinkTile extends StatelessWidget {
  const RefundLinkTile({
    super.key,
    required this.refund,
    required this.linkedId,
    required this.onChanged,
  });

  final TransactionModel refund; // the saved refund being edited
  final int? linkedId; // current choice on the form
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TransactionProvider>();
    final e = txns.byId(linkedId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link),
      title: Text(
        e == null
            ? 'Link to the expense it refunds'
            : 'Refund of: ${_name(txns, e)} ${formatPaise(e.amountPaise)} · '
                  '${DateFormat('d MMM').format(e.dateTime)}',
      ),
      subtitle: Text(e == null ? 'Optional' : 'Tap to change'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () async {
        final pick = await pickRefundExpense(
          context,
          refund.withRefundOf(linkedId),
          allowUnlink: true,
        );
        if (pick != null) onChanged(pick.expenseId);
      },
    );
  }
}

/// Merchant, or the category name when there is no merchant.
String _name(TransactionProvider txns, TransactionModel? e) {
  if (e == null) return 'expense';
  final m = (e.merchant ?? '').trim();
  return m.isNotEmpty
      ? m
      : (txns.categoryById(e.categoryId)?.name ?? 'Expense');
}
