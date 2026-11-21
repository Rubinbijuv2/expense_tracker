import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_payment.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/placeholder_body.dart';
import 'recurring_detail_screen.dart';
import 'recurring_form_screen.dart';
import 'recurring_tile.dart';

/// All repeat payments, grouped by type, with next due date and status.
/// Opened from Settings → Repeat payments and from the Home Upcoming card.
class RecurringListScreen extends StatelessWidget {
  const RecurringListScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RecurringListScreen()));

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecurringProvider>();
    final txns = context.watch<TransactionProvider>();
    final groups = rec.byType;

    Widget body;
    if (rec.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (rec.error != null) {
      body = const PlaceholderBody(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: 'Could not load repeat payments. Restart the app.',
      );
    } else if (groups.isEmpty) {
      body = const PlaceholderBody(
        icon: Icons.event_repeat,
        title: 'No repeat payments yet',
        message:
            'Add bills, subscriptions, EMIs, chitti or class fees '
            'to see when each one is due.\nTap + to add one.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: rec.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final entry in groups.entries) ...[
              _GroupHeader(
                title: RecurringPayment.typeLabel(entry.key),
                count: entry.value.length,
              ),
              for (final p in entry.value)
                RecurringTile(
                  item: p,
                  category: txns.categoryById(p.categoryId),
                  state: rec.stateOf(p),
                  next: rec.nextPending(p.id!),
                  progress: rec.progressOf(p),
                  onTap: () => RecurringDetailScreen.open(context, p.id!),
                ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Repeat payments')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_recurring',
        onPressed: () => RecurringFormScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: body,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
