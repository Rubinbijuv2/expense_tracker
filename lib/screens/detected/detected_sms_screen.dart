import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../models/detected_sms.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/placeholder_body.dart';
import '../add_edit/add_edit_screen.dart';
import 'detected_sms_card.dart';
import 'merge_card.dart';

/// All pending suggestions made from bank SMS. A Bank + Receipt pair about
/// the same payment is shown as one merge card.
class DetectedSmsScreen extends StatelessWidget {
  const DetectedSmsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DetectedSmsScreen()));

  @override
  Widget build(BuildContext context) {
    final detected = context.watch<DetectedSmsProvider>();
    final txns = context.watch<TransactionProvider>();
    final pending = detected.pending;
    final cards = detected.cards;

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
      body: detected.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: detected.load,
              child: pending.isEmpty
                  ? ListView(
                      // A ListView (not just a Column) so pull-to-refresh works.
                      children: const [
                        SizedBox(height: 120),
                        PlaceholderBody(
                          icon: Icons.mark_email_read_outlined,
                          title: 'All caught up',
                          message:
                              'New bank SMS will appear here as suggestions.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cards.length,
                      itemBuilder: (context, i) {
                        final card = cards[i];
                        CategoryModel? catOf(DetectedSms s) =>
                            s.guessedCategoryId == null
                                ? null
                                : txns.categoryById(s.guessedCategoryId!);
                        if (card.length == 2) {
                          final (bank, receipt) = (card[0], card[1]);
                          return MergeCard(
                            key: ValueKey('pair-${bank.id}'),
                            bank: bank,
                            receipt: receipt,
                            receiptCategory: catOf(receipt),
                            onMerge: () => _merge(context, bank, receipt),
                            onNotSame: () => detected.unpair(bank, receipt),
                            onIgnoreBoth: () async {
                              await detected.ignore(bank);
                              await detected.ignore(receipt);
                            },
                          );
                        }
                        final sms = card.first;
                        return DetectedSmsCard(
                          key: ValueKey(sms.id),
                          sms: sms,
                          category: catOf(sms),
                          onSave: () => _save(context, sms),
                          onEdit: () => AddEditScreen.openFromSms(context, sms),
                          onIgnore: () => _ignore(context, sms),
                          onIgnoreSender: () => _ignoreSender(context, sms),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _save(BuildContext context, DetectedSms sms) async {
    // The guessed category was deleted: let the user pick one.
    if (sms.guessedCategoryId == null ||
        context.read<TransactionProvider>().categoryById(
              sms.guessedCategoryId!,
            ) ==
            null) {
      await AddEditScreen.openFromSms(context, sms);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<DetectedSmsProvider>().save(sms);
      messenger.showSnackBar(
        SnackBar(content: Text('Saved ${formatPaise(sms.amountPaise)}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  Future<void> _ignore(BuildContext context, DetectedSms sms) async {
    final provider = context.read<DetectedSmsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.ignore(sms);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Ignored'),
        persist: false,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => provider.restorePending(sms),
        ),
      ),
    );
  }

  Future<void> _merge(
    BuildContext context,
    DetectedSms bank,
    DetectedSms receipt,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<DetectedSmsProvider>().merge(bank, receipt);
    messenger.showSnackBar(
      const SnackBar(content: Text('Merged into one card. Tap Save to add it.')),
    );
  }

  /// "Always ignore this sender" (rule 14): asks first, because it also
  /// removes every pending card from that sender.
  Future<void> _ignoreSender(BuildContext context, DetectedSms sms) async {
    final provider = context.read<DetectedSmsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Always ignore ${sms.sender}?'),
        content: const Text(
          'New SMS from this sender will not be detected, and its waiting '
          'cards are removed. Saved transactions are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Always ignore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final n = await provider.ignoreSender(sms.sender);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${sms.sender} ignored · $n card${n == 1 ? '' : 's'} removed',
        ),
      ),
    );
  }

  Future<void> _ignoreAll(BuildContext context) async {
    final provider = context.read<DetectedSmsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ignore all detected SMS?'),
        content: Text(
          '${provider.pending.length} suggestions will be removed '
          'from this list. Your transactions are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ignore all'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.ignoreAll();
  }
}
