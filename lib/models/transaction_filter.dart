/// What the user is looking for on the History screen: search text plus
/// filters. Immutable: every change makes a new object with [copyWith].
///
/// [toWhere] turns it into an SQL `WHERE` clause with `?` placeholders,
/// so the database does the filtering and user text is never put into SQL.
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.from,
    this.to,
    this.categoryIds = const {},
    this.paymentModes = const {},
    this.minPaise,
    this.maxPaise,
    this.type,
  });

  /// Matched against note and merchant (case-insensitive, anywhere in the text).
  final String query;

  /// First and last day of the date range, both included. Time is ignored.
  final DateTime? from;
  final DateTime? to;

  /// Empty set = any category / any payment mode.
  final Set<int> categoryIds;
  final Set<String> paymentModes;

  /// Amount limits in paise, both included.
  final int? minPaise;
  final int? maxPaise;

  /// 'expense', 'income' or null for both.
  final String? type;

  bool get hasDateRange => from != null || to != null;
  bool get hasAmountRange => minPaise != null || maxPaise != null;

  /// Number of filters switched on (search text not counted).
  /// Shown as the badge on the filter button.
  int get activeCount =>
      (hasDateRange ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (paymentModes.isNotEmpty ? 1 : 0) +
      (hasAmountRange ? 1 : 0) +
      (type != null ? 1 : 0);

  bool get hasFilters => activeCount > 0;
  bool get isEmpty => !hasFilters && query.trim().isEmpty;

  /// Dart cannot tell "leave as is" from "set to null" with a plain nullable
  /// parameter, so the `clear…` flags are used to remove a value.
  TransactionFilter copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    Set<int>? categoryIds,
    Set<String>? paymentModes,
    int? minPaise,
    int? maxPaise,
    bool clearAmounts = false,
    String? type,
    bool clearType = false,
  }) =>
      TransactionFilter(
        query: query ?? this.query,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        categoryIds: categoryIds ?? this.categoryIds,
        paymentModes: paymentModes ?? this.paymentModes,
        minPaise: clearAmounts ? null : (minPaise ?? this.minPaise),
        maxPaise: clearAmounts ? null : (maxPaise ?? this.maxPaise),
        type: clearType ? null : (type ?? this.type),
      );

  /// Keeps the search text, removes every filter.
  TransactionFilter clearFilters() => TransactionFilter(query: query);

  /// Builds the `WHERE` text and its values, e.g.
  /// `('type = ? AND amount_paise >= ?', ['expense', 10000])`.
  /// Returns `(null, [])` when nothing is filtered (= all rows).
  ///
  /// Only `?` placeholders are added to the SQL text; every user value goes
  /// into the list, which sqflite passes to SQLite separately.
  (String?, List<Object?>) toWhere() {
    final parts = <String>[];
    final args = <Object?>[];

    final q = query.trim();
    if (q.isNotEmpty) {
      // `\` is declared as the escape character, so a typed % or _ is
      // matched literally instead of acting as a LIKE wildcard.
      parts.add(r"(note LIKE ? ESCAPE '\' OR merchant LIKE ? ESCAPE '\')");
      final pattern = '%${escapeLike(q)}%';
      args..add(pattern)..add(pattern);
    }

    if (from != null) {
      parts.add('date_time >= ?');
      args.add(_startOfDay(from!).toIso8601String());
    }
    if (to != null) {
      // Before the start of the next day, so the whole "to" day is included.
      parts.add('date_time < ?');
      args.add(_startOfDay(to!).add(const Duration(days: 1)).toIso8601String());
    }

    if (categoryIds.isNotEmpty) {
      parts.add('category_id IN (${_placeholders(categoryIds.length)})');
      args.addAll(categoryIds.toList()..sort());
    }
    if (paymentModes.isNotEmpty) {
      parts.add('payment_mode IN (${_placeholders(paymentModes.length)})');
      args.addAll(paymentModes.toList()..sort());
    }

    if (minPaise != null) {
      parts.add('amount_paise >= ?');
      args.add(minPaise);
    }
    if (maxPaise != null) {
      parts.add('amount_paise <= ?');
      args.add(maxPaise);
    }

    if (type != null) {
      parts.add('type = ?');
      args.add(type);
    }

    return (parts.isEmpty ? null : parts.join(' AND '), args);
  }

  /// Puts `\` before `\`, `%` and `_` so LIKE treats them as normal letters.
  static String escapeLike(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// "?, ?, ?" for [n] values (only placeholders, never values).
  static String _placeholders(int n) => List.filled(n, '?').join(', ');

  // A DateTime made with year/month/day only is midnight in local time,
  // matching how date_time is stored.
  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
