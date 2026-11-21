import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/recurring_provider.dart';
import '../../services/dialer_service.dart';
import '../../services/recurring_action_service.dart';
import '../../services/reminder_planner.dart';
import 'amount_dialog.dart';
import 'recurring_detail_screen.dart';

/// A repeat-payment reminder opened the app:
/// - tapped the notification → open that repeat payment;
/// - "Mark as paid" on a chitti → open it and ask the amount (pre-filled);
/// - "Call organiser" → open the phone dialer with the organiser's number.
///
/// [context] is the Navigator's context (from main.dart's navigatorKey).
Future<void> handleReminderResponse(
  BuildContext context,
  String? actionId,
  ReminderPayload payload,
) async {
  final rec = context.read<RecurringProvider>();
  final messenger = ScaffoldMessenger.of(context);
  await rec.ensureLoaded();
  if (!context.mounted) return;
  final p = rec.byId(payload.recurringId);
  if (p == null) return; // deleted since the reminder was scheduled

  if (actionId == RecurringActionService.callAction) {
    if (!await DialerService.dial(p.organiserPhone)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer')),
      );
    }
    return;
  }

  // Not awaited: the detail screen stays open under the dialog.
  RecurringDetailScreen.open(context, p.id!);
  if (actionId != RecurringActionService.markPaidAction) return;

  final inst = rec.installmentById(p.id!, payload.installmentId);
  if (inst == null || !inst.isPending) {
    messenger.showSnackBar(
      SnackBar(content: Text('${p.name} is already marked as paid')),
    );
    return;
  }
  final choice = await showMarkPaidDialog(context, p, inst);
  if (choice == null) return;
  try {
    await rec.markPaid(
      p,
      inst,
      choice.amountPaise,
      addTransaction: choice.addTransaction,
    );
    messenger.showSnackBar(SnackBar(content: Text('${p.name} marked as paid')));
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save. Please try again.')),
    );
  }
}
