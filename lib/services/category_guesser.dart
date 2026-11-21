/// Guesses a category for a merchant name (PLAN.md section 4, rule 9).
///
/// Pure Dart: no Flutter imports, so it can be unit-tested without a phone.
library;

import '../models/merchant_rule.dart';

/// The result of a guess. Exactly one of the two fields is set:
/// - [categoryId] when a learned merchant rule matched (rules store ids);
/// - [categoryName] when the built-in keyword map (or the 'Others' fallback)
///   was used. The caller looks up the id for that name in the categories table.
class CategoryGuess {
  final int? categoryId;
  final String? categoryName;

  const CategoryGuess.fromRule(int this.categoryId) : categoryName = null;
  const CategoryGuess.fromName(String this.categoryName) : categoryId = null;

  bool get isFromRule => categoryId != null;

  @override
  String toString() => isFromRule
      ? 'CategoryGuess(id $categoryId)'
      : 'CategoryGuess($categoryName)';
}

class CategoryGuesser {
  CategoryGuesser._();

  static const String fallback = 'Others';

  /// Keyword → default category name (names match data/default_categories.dart).
  static const Map<String, String> keywordMap = {
    'swiggy': 'Food',
    'zomato': 'Food',
    'dominos': 'Food',
    'uber': 'Travel',
    'ola': 'Travel',
    'rapido': 'Travel',
    'irctc': 'Travel',
    'redbus': 'Travel',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'meesho': 'Shopping',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vi': 'Bills',
    'bescom': 'Bills',
    'electricity': 'Bills',
    'recharge': 'Bills',
    'netflix': 'Entertainment',
    'hotstar': 'Entertainment',
    'spotify': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'apollo': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
  };

  /// 1. Learned [rules] first (the longest matching keyword wins).
  /// 2. Then the built-in [keywordMap].
  /// 3. Otherwise 'Others'.
  static CategoryGuess guess(String merchant, List<MerchantRule> rules) {
    final name = merchant.toLowerCase();

    final sorted = [...rules]
      ..sort((a, b) => b.keyword.length.compareTo(a.keyword.length));
    for (final rule in sorted) {
      final keyword = rule.keyword.trim().toLowerCase();
      if (keyword.isNotEmpty && _matches(name, keyword)) {
        return CategoryGuess.fromRule(rule.categoryId);
      }
    }

    for (final entry in keywordMap.entries) {
      if (_matches(name, entry.key)) return CategoryGuess.fromName(entry.value);
    }
    return const CategoryGuess.fromName(fallback);
  }

  /// Short keywords (3 letters or fewer, like 'vi' or 'ola') must be a whole
  /// word, so "Ravi" is not Bills and "Motorola" is not Travel.
  /// Longer keywords may appear inside a word ("Swiggyinstamart").
  static bool _matches(String name, String keyword) {
    if (keyword.length > 3) return name.contains(keyword);
    return RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(name);
  }
}
