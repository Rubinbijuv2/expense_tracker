import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_payment.dart';
import '../../providers/repeat_suggestion_provider.dart';
import '../../services/installment_schedule.dart';
import '../../services/recurring_suggester.dart';
import '../recurring/recurring_form_screen.dart';

/// "Paid Netflix ₹199 for 3 months. Make it a repeat payment?" (PLAN.md 5.5).
/// Shows the biggest suggestion only, so Home doesn't fill up with cards.
class RepeatSuggestionCard extends StatelessWidget {
  const RepeatSuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepeatSuggestionProvider>();
    final list = provider.suggestions;
    if (list.isEmpty) return const SizedBox.shrink();
    final s = list.first;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paid ${s.merchant} ${shortRupees(s.amountPaise)} for '
                    '${RecurringSuggester.months} months. '
                    'Make it a repeat payment?',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => provider.dismiss(s),
                  child: const Text('Not now'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: () => _create(context, s),
                  child: const Text('Make repeat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the Add repeat payment form, filled in from the suggestion.
  /// The card disappears by itself once it is saved (the name now matches).
  void _create(BuildContext context, RepeatSuggestion s) {
    final now = DateTime.now();
    RecurringFormScreen.open(
      context,
      prefill: RecurringPayment(
        name: s.merchant,
        type: 'bill',
        amountPaise: s.amountPaise,
        categoryId: s.categoryId,
        dueDay: s.dueDay,
        startDate: DateTime(now.year, now.month, now.day),
        paymentMode: s.paymentMode,
        matchKeyword: s.merchant,
      ),
    );
  }
}
