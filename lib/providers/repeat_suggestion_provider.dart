import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/recurring_suggester.dart';
import 'recurring_provider.dart';
import 'transaction_provider.dart';

/// "Paid Netflix ₹199 for 3 months. Make it a repeat payment?" cards on
/// Home (PLAN.md 5.5). Remembers "Not now" in shared_preferences.
class RepeatSuggestionProvider extends ChangeNotifier {
  RepeatSuggestionProvider(this._txns, this._recurring) {
    // Recompute whenever transactions or repeat payments change.
    _txns.addListener(notifyListeners);
    _recurring.addListener(notifyListeners);
    loadDismissed();
  }

  final TransactionProvider _txns;
  final RecurringProvider _recurring;
  Set<String> _dismissed = {};

  static const String _key = RecurringSuggester.dismissedKey;

  List<RepeatSuggestion> get suggestions {
    if (_txns.isLoading || _recurring.isLoading) return const [];
    return RecurringSuggester.suggest(
      transactions: _txns.transactions,
      recurring: _recurring.items,
      dismissed: _dismissed,
      today: DateTime.now(),
    );
  }

  /// Reads the "Not now" list again (also after "Delete all data").
  Future<void> loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed = (prefs.getStringList(_key) ?? const []).toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Could not read dismissed suggestions: $e');
    }
  }

  /// "Not now": never suggest this merchant again.
  Future<void> dismiss(RepeatSuggestion s) async {
    _dismissed = {..._dismissed, s.key};
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _dismissed.toList());
    } catch (e) {
      debugPrint('Could not save dismissed suggestion: $e');
    }
  }

  @override
  void dispose() {
    _txns.removeListener(notifyListeners);
    _recurring.removeListener(notifyListeners);
    super.dispose();
  }
}
