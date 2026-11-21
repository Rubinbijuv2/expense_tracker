import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/budget_repo.dart';
import '../utils/formatters.dart';

/// When a new month starts with no budgets, copies the latest earlier
/// month's budgets into it, so Home never says "Set a budget" just because
/// the month changed.
///
/// It runs at most once per month (remembered in shared_preferences), so if
/// the user removes a budget on purpose it does not come back.
class BudgetCarryOver {
  BudgetCarryOver._();

  static const String _doneKey = 'budget_carried_month'; // 'YYYY-MM'

  // Home and Budgets both call this at start-up; they share one run so the
  // budgets are never copied twice.
  static Future<void>? _running;
  static String? _doneFor;

  /// Safe to call often; does real work once per month. Never throws.
  static Future<void> ensureCurrentMonth({BudgetRepo? repo}) {
    final key = monthKey(DateTime.now());
    if (_doneFor == key) return Future.value();
    return _running ??= _run(repo ?? BudgetRepo(), key).whenComplete(() {
      _doneFor = key;
      _running = null;
    });
  }

  static Future<void> _run(BudgetRepo repo, String month) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_doneKey) == month) return;
      if ((await repo.getForMonth(month)).isEmpty) {
        final n = await repo.copyFromLatestBefore(month);
        if (n > 0) debugPrint('Carried $n budget(s) over to $month');
      }
      await prefs.setString(_doneKey, month);
    } catch (e) {
      debugPrint('Budget carry-over skipped: $e');
    }
  }
}
