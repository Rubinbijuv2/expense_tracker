import '../models/category_model.dart';
import '../models/transaction_model.dart';

/// Pure rules for linking a refund to the expense it pays back
/// (PLAN.md section 6.2). No database, so it is unit-tested.
class RefundMatcher {
  RefundMatcher._();

  /// Only expenses this many days before the refund are offered.
  static const int windowDays = 60;
  static const int maxResults = 10;

  /// True for the income category named "Refund".
  static bool isRefundCategory(CategoryModel? c) =>
      c != null &&
      c.type == 'income' &&
      c.name.trim().toLowerCase() == 'refund';

  /// How much has been refunded on each expense: expense id → paise.
  /// Refunds pointing at deleted expenses are simply never looked up.
  static Map<int, int> refundedTotals(Iterable<TransactionModel> all) {
    final totals = <int, int>{};
    for (final t in all) {
      final of = t.refundOfId;
      if (of == null || t.isExpense) continue;
      totals[of] = (totals[of] ?? 0) + t.amountPaise;
    }
    return totals;
  }

  /// Expenses that [refund] could belong to:
  /// - expenses (not self transfers) from the [windowDays] before the refund;
  /// - if the refund has a merchant: same merchant (case does not matter);
  ///   without one (manual entry): at least as much as the refund;
  /// - not already fully refunded by *other* refunds.
  /// Same amount first, then newest first; at most [maxResults].
  static List<TransactionModel> candidates(
    TransactionModel refund,
    List<TransactionModel> all,
  ) {
    final merchant = _key(refund.merchant);
    final from = refund.dateTime.subtract(const Duration(days: windowDays));
    final refunded = refundedTotals(all.where((t) => t.id != refund.id));

    final list = all.where((e) {
      if (!e.isExpense || !e.counts || e.id == null) return false;
      if (e.dateTime.isAfter(refund.dateTime) || e.dateTime.isBefore(from)) {
        return false;
      }
      if ((refunded[e.id] ?? 0) >= e.amountPaise) return false;
      return merchant == null
          ? e.amountPaise >= refund.amountPaise
          : _key(e.merchant) == merchant;
    }).toList();

    list.sort((a, b) {
      final aSame = a.amountPaise == refund.amountPaise ? 0 : 1;
      final bSame = b.amountPaise == refund.amountPaise ? 0 : 1;
      if (aSame != bSame) return aSame - bSame;
      return b.dateTime.compareTo(a.dateTime);
    });
    return list.length > maxResults ? list.sublist(0, maxResults) : list;
  }

  /// Lower-case merchant, or null when there is none ("Unknown" counts as none).
  static String? _key(String? merchant) {
    final m = (merchant ?? '').trim().toLowerCase();
    return m.isEmpty || m == 'unknown' ? null : m;
  }
}
