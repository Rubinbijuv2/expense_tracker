import 'transaction_model.dart';

/// Total spent in one month (one bar of the 6-month bar chart).
class MonthTotal {
  const MonthTotal(this.month, this.spentPaise);

  final DateTime month; // first day of the month
  final int spentPaise;
}

/// Total spent at one merchant in a month (one row of "Top merchants").
class MerchantTotal {
  const MerchantTotal(this.name, this.totalPaise, this.count);

  final String name;
  final int totalPaise;
  final int count; // number of transactions
}

/// Everything the Reports screen and the exports show for one month.
/// Pure Dart (no database, no Flutter), so it is easy to unit-test.
class ReportSummary {
  const ReportSummary({
    required this.month,
    required this.spentPaise,
    required this.incomePaise,
    required this.lastSixMonths,
    required this.dailySpentPaise,
    required this.topMerchants,
    required this.transactions,
    required this.daysCounted,
  });

  /// First day of the month this report is for.
  final DateTime month;
  final int spentPaise;
  final int incomePaise;

  /// Oldest first; the last item is [month] itself.
  final List<MonthTotal> lastSixMonths;

  /// Spending per day: index 0 is day 1. Length = days in the month.
  final List<int> dailySpentPaise;

  /// Biggest first, at most [topMerchantCount] items. Expenses only.
  final List<MerchantTotal> topMerchants;

  /// All transactions (expense and income) of the month, newest first.
  final List<TransactionModel> transactions;

  /// Days used for the average: days so far for the current month,
  /// every day of the month for past months.
  final int daysCounted;

  static const int topMerchantCount = 5;
  static const int monthsInBarChart = 6;
  static const String unknownMerchant = 'Unknown';

  int get balancePaise => incomePaise - spentPaise;

  int get daysInMonth => dailySpentPaise.length;

  /// Average spent per day in whole paise (rounded down).
  int get averagePerDayPaise => daysCounted == 0 ? 0 : spentPaise ~/ daysCounted;

  /// Builds the report for the month containing [month].
  /// [txns] must be sorted newest first (as TransactionProvider keeps them).
  /// [today] is only passed by tests; the app uses the real date.
  static ReportSummary compute(
    List<TransactionModel> txns,
    DateTime month, {
    DateTime? today,
  }) {
    final m = DateTime(month.year, month.month);
    final now = today ?? DateTime.now();
    final days = DateTime(m.year, m.month + 1, 0).day; // day 0 = last day of m

    // Bar chart: the 6 months ending with m. `month - 5` works across years
    // because DateTime(2026, -1) becomes November 2025.
    final barMonths = [
      for (var i = monthsInBarChart - 1; i >= 0; i--) DateTime(m.year, m.month - i)
    ];
    final spentPerMonth = {for (final bm in barMonths) bm: 0};

    var spent = 0;
    var income = 0;
    final daily = List<int>.filled(days, 0);
    final merchants = <String, _MerchantSum>{}; // lower-case name → sum
    final monthTxns = <TransactionModel>[];

    for (final t in txns) {
      final tm = DateTime(t.dateTime.year, t.dateTime.month);
      if (t.isExpense && spentPerMonth.containsKey(tm)) {
        spentPerMonth[tm] = spentPerMonth[tm]! + t.amountPaise;
      }
      if (tm != m) continue;

      monthTxns.add(t);
      if (!t.isExpense) {
        income += t.amountPaise;
        continue;
      }
      spent += t.amountPaise;
      daily[t.dateTime.day - 1] += t.amountPaise;

      final name = (t.merchant ?? '').trim();
      final display = name.isEmpty ? unknownMerchant : name;
      // The newest spelling is kept because the list is newest first.
      final sum = merchants.putIfAbsent(
          display.toLowerCase(), () => _MerchantSum(display));
      sum.paise += t.amountPaise;
      sum.count++;
    }

    final top = merchants.values
        .map((s) => MerchantTotal(s.name, s.paise, s.count))
        .toList()
      ..sort((a, b) => b.totalPaise.compareTo(a.totalPaise));

    final thisMonth = DateTime(now.year, now.month);
    final int daysCounted;
    if (m == thisMonth) {
      daysCounted = now.day;
    } else if (m.isAfter(thisMonth)) {
      daysCounted = 0;
    } else {
      daysCounted = days;
    }

    return ReportSummary(
      month: m,
      spentPaise: spent,
      incomePaise: income,
      lastSixMonths: [for (final bm in barMonths) MonthTotal(bm, spentPerMonth[bm]!)],
      dailySpentPaise: daily,
      topMerchants: top.take(topMerchantCount).toList(),
      transactions: monthTxns,
      daysCounted: daysCounted,
    );
  }
}

/// Running total while grouping by merchant.
class _MerchantSum {
  _MerchantSum(this.name);

  final String name;
  int paise = 0;
  int count = 0;
}
