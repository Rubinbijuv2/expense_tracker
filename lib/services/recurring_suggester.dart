import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

/// "Paid Netflix ₹199 for 3 months. Make it a repeat payment?"
class RepeatSuggestion {
  const RepeatSuggestion({
    required this.key,
    required this.merchant,
    required this.amountPaise,
    required this.categoryId,
    required this.paymentMode,
    required this.dueDay,
  });

  /// Lower-case merchant, used to remember "Not now".
  final String key;
  final String merchant; // as written in the latest transaction
  final int amountPaise; // latest month's amount
  final int categoryId;
  final String paymentMode;
  final int dueDay; // day of the month of the latest payment
}

/// Pure rule from PLAN.md section 5.5: the same merchant with a similar
/// amount (±5%) in 3 consecutive months, not linked to a repeat payment.
class RecurringSuggester {
  RecurringSuggester._();

  static const int months = 3;
  static const int percent = 5;

  static String keyOf(String? merchant) =>
      (merchant ?? '').trim().toLowerCase();

  static List<RepeatSuggestion> suggest({
    required List<TransactionModel> transactions,
    required List<RecurringPayment> recurring,
    required Set<String> dismissed,
    required DateTime today,
  }) {
    // Merchants that already belong to a repeat payment.
    final linked = <String>{
      for (final p in recurring) keyOf(p.name),
      for (final p in recurring)
        if ((p.matchKeyword ?? '').trim().isNotEmpty) keyOf(p.matchKeyword),
      for (final t in transactions)
        if (t.recurringId != null) keyOf(t.merchant),
    };

    // merchant → month 'YYYY-MM' → that month's expenses
    final byMerchant = <String, Map<String, List<TransactionModel>>>{};
    for (final t in transactions) {
      final key = keyOf(t.merchant);
      if (!t.isExpense || !t.counts || t.recurringId != null) continue;
      if (key.isEmpty || key == 'unknown') continue;
      if (linked.contains(key) || dismissed.contains(key)) continue;
      byMerchant
          .putIfAbsent(key, () => {})
          .putIfAbsent(monthKey(t.dateTime), () => [])
          .add(t);
    }

    final out = <RepeatSuggestion>[];
    byMerchant.forEach((key, perMonth) {
      // The run may end this month or last month (not paid yet this month).
      for (final endBack in [0, 1]) {
        final s = _check(key, perMonth, today, endBack);
        if (s != null) {
          out.add(s);
          break;
        }
      }
    });
    out.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
    return out;
  }

  static RepeatSuggestion? _check(
    String key,
    Map<String, List<TransactionModel>> perMonth,
    DateTime today,
    int endBack,
  ) {
    String monthAt(int back) =>
        monthKey(DateTime(today.year, today.month - endBack - back));
    final latest = perMonth[monthAt(0)];
    if (latest == null) return null;
    final sorted = [...latest]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    for (final t in sorted) {
      var ok = true;
      for (var back = 1; back < months && ok; back++) {
        final list = perMonth[monthAt(back)] ?? const <TransactionModel>[];
        ok = list.any((o) => _similar(o.amountPaise, t.amountPaise));
      }
      if (ok) {
        return RepeatSuggestion(
          key: key,
          merchant: t.merchant!.trim(),
          amountPaise: t.amountPaise,
          categoryId: t.categoryId,
          paymentMode: t.paymentMode,
          dueDay: t.dateTime.day,
        );
      }
    }
    return null;
  }

  static bool _similar(int a, int ref) =>
      (a - ref).abs() * 100 <= ref * percent;
}
