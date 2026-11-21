import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/detected_sms.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/placeholder_body.dart';
import '../add_edit/add_edit_screen.dart';
import 'detected_sms_card.dart';

/// All pending suggestions made from bank SMS.
class DetectedSmsScreen extends StatelessWidget {
  const DetectedSmsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const DetectedSmsScreen()));

  @override
  Widget build(BuildContext context) {
    final detected = context.watch<DetectedSmsProvider>();
    final txns = context.watch<TransactionProvider>();
    final pending = detected.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected SMS'),
        actions: [
          TextButton(
            onPressed: pending.isEmpty ? null : () => _ignoreAll(context),
            child: const Text('Ignore all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: detected.load,
        child: pending.isEmpty
            ? ListView(
                // A ListView (not just a Column) so pull-to-refresh works.
                children: const [
                  SizedBox(height: 120),
                  PlaceholderBody(
                    icon: Icons.mark_email_read_outlined,
                    title: 'All caught up',
                    message: 'New bank SMS will appear here as suggestions.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pending.length,
                itemBuilder: (context, i) {
                  final sms = pending[i];
                  final cat = sms.guessedCategoryId == null
                      ? null
                      : txns.categoryById(sms.guessedCategoryId!);
                  return DetectedSmsCard(
                    key: ValueKey(sms.id),
                    sms: sms,
                    category: cat,
                    onSave: () => _save(context, sms),
                    onEdit: () => AddEditScreen.openFromSms(context, sms),
                    onIgnore: () => _ignore(context, sms),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _save(BuildContext context, DetectedSms sms) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<DetectedSmsProvider>().save(sms);
      messenger.showSnackBar(SnackBar(
          content: Text('Saved ${formatPaise(sms.amountPaise)}')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')));
    }
  }

  Future<void> _ignore(BuildContext context, DetectedSms sms) async {
    final provider = context.read<DetectedSmsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.ignore(sms);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: const Text('Ignored'),
      persist: false,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => provider.restorePending(sms),
      ),
    ));
  }

  Future<void> _ignoreAll(BuildContext context) async {
    final provider = context.read<DetectedSmsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ignore all detected SMS?'),
        content: Text('${provider.pending.length} suggestions will be removed '
            'from this list. Your transactions are not changed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ignore all')),
        ],
      ),
    );
    if (ok == true) await provider.ignoreAll();
  }
}
