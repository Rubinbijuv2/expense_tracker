import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_installment.dart';
import '../../models/recurring_payment.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/dialer_service.dart';
import '../../services/installment_schedule.dart';
import '../../widgets/placeholder_body.dart';
import 'amount_dialog.dart';
import 'installment_tile.dart';
import 'recurring_form_screen.dart';
import 'recurring_summary_card.dart';

/// One repeat payment: summary, progress, Mark as paid / Skip, chitti
/// received, and the full installment history.
class RecurringDetailScreen extends StatelessWidget {
  const RecurringDetailScreen({super.key, required this.id});

  final int id;

  static Future<void> open(BuildContext context, int id) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => RecurringDetailScreen(id: id)));

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecurringProvider>();
    final txns = context.watch<TransactionProvider>();
    final p = rec.byId(id);
    if (p == null) {
      // Deleted (or the data was reset) while this screen was open.
      return Scaffold(
        appBar: AppBar(),
        body: rec.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const PlaceholderBody(
                icon: Icons.event_busy,
                title: 'Repeat payment not found',
                message: 'It may have been deleted. Go back to see the list.',
              ),
      );
    }
    final insts = rec.installmentsOf(id);
    final next = rec.nextPending(id);
    final today = InstallmentSchedule.dateOnly(DateTime.now());
    final hasEarlier = insts.any(
      (i) => i.isPending && i.dueDate.isBefore(today),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          if (p.isChitti && (p.organiserPhone ?? '').isNotEmpty)
            IconButton(
              tooltip: 'Call organiser',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => DialerService.dial(p.organiserPhone),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => RecurringFormScreen.open(context, item: p),
          ),
          PopupMenuButton<String>(
            onSelected: (v) =>
                v == 'delete' ? _delete(context, p) : _markEarlier(context, p),
            itemBuilder: (_) => [
              if (hasEarlier)
                const PopupMenuItem(
                  value: 'earlier',
                  child: Text('Mark earlier ones as paid'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          RecurringSummaryCard(
            item: p,
            category: txns.categoryById(p.categoryId),
            state: rec.stateOf(p),
            next: next,
            progress: rec.progressOf(p),
          ),
          if (p.active && next != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _markPaid(context, p, next),
                      icon: const Icon(Icons.check),
                      label: const Text('Mark as paid'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _skip(context, p, next),
                      icon: const Icon(Icons.redo),
                      label: Text(switch (p.frequency) {
                        'weekly' => 'Skip this week',
                        'yearly' => 'Skip this year',
                        _ => 'Skip this month',
                      }),
                    ),
                  ),
                ],
              ),
            ),
          if (p.isChitti)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: p.chittiReceived
                  ? TextButton.icon(
                      onPressed: () => _undoReceived(context, p),
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo "chitti received"'),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _received(context, p),
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text('I received the chitti'),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('History', style: theme.textTheme.titleMedium),
          ),
          if (insts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No installments yet.'),
            ),
          // Newest first; number = position in the schedule (oldest is #1).
          for (var i = insts.length - 1; i >= 0; i--)
            InstallmentTile(
              inst: insts[i],
              number: i + 1,
              onTap: () => _installmentActions(context, p, insts[i]),
            ),
        ],
      ),
    );
  }

  // ---- Actions ---------------------------------------------------------------

  void _snack(ScaffoldMessengerState m, String text, {SnackBarAction? action}) {
    m.clearSnackBars();
    m.showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _markPaid(
    BuildContext context,
    RecurringPayment p,
    RecurringInstallment inst,
  ) async {
    final rec = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showMarkPaidDialog(context, p, inst);
    if (choice == null) return;
    try {
      await rec.markPaid(
        p,
        inst,
        choice.amountPaise,
        addTransaction: choice.addTransaction,
      );
      _snack(messenger, '${p.name} marked as paid');
    } catch (e) {
      _snack(messenger, 'Could not save. Please try again.');
    }
  }

  Future<void> _skip(
    BuildContext context,
    RecurringPayment p,
    RecurringInstallment inst,
  ) async {
    final rec = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await rec.skip(p, inst);
    _snack(
      messenger,
      'Skipped',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => rec.undo(p, inst.withStatus('skipped')),
      ),
    );
  }

  /// Tapping a row in the history: pay / skip a pending one, or undo.
  Future<void> _installmentActions(
    BuildContext context,
    RecurringPayment p,
    RecurringInstallment inst,
  ) async {
    final rec = context.read<RecurringProvider>();
    final action = await showInstallmentActions(context, inst);
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'pay':
        await _markPaid(context, p, inst);
      case 'skip':
        await _skip(context, p, inst);
      case 'undo':
        await rec.undo(p, inst);
    }
  }

  Future<void> _markEarlier(BuildContext context, RecurringPayment p) async {
    final rec = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      'Mark earlier ones as paid?',
      'Every unpaid installment due before today is marked paid at '
          'the usual amount. No expenses are added, so use this for '
          'payments made before you started using the app.',
      'Mark paid',
    );
    if (!ok) return;
    final n = await rec.markEarlierPaid(p);
    _snack(messenger, '$n installment${n == 1 ? '' : 's'} marked as paid');
  }

  Future<void> _received(BuildContext context, RecurringPayment p) async {
    final rec = context.read<RecurringProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showChittiReceivedDialog(context);
    if (choice == null) return;
    try {
      await rec.chittiReceived(p, choice.amountPaise, choice.date);
      _snack(messenger, 'Saved as income in Chitti received');
    } catch (e) {
      _snack(messenger, 'Could not save. Please try again.');
    }
  }

  Future<void> _undoReceived(BuildContext context, RecurringPayment p) async {
    final rec = context.read<RecurringProvider>();
    final ok = await _confirm(
      context,
      'Undo chitti received?',
      'The income transaction it added will be deleted.',
      'Undo',
    );
    if (ok) await rec.undoChittiReceived(p);
  }

  Future<void> _delete(BuildContext context, RecurringPayment p) async {
    final rec = context.read<RecurringProvider>();
    final nav = Navigator.of(context);
    final ok = await _confirm(
      context,
      'Delete ${p.name}?',
      'Its installment history is deleted. Expenses already saved stay '
          'in your transactions.',
      'Delete',
    );
    if (!ok) return;
    nav.pop();
    await rec.delete(p);
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
    String okLabel,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
