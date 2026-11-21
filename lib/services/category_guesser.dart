/// Guesses a category for a detected SMS (PLAN.md section 4, rule 10).
///
/// Pure Dart: no Flutter imports, so it can be unit-tested without a phone.
library;

import '../models/merchant_rule.dart';
import 'sms_parser.dart';

/// The result of a guess. Exactly one of the two fields is set:
/// - [categoryId] when a learned merchant rule matched (rules store ids);
/// - [categoryName] when the built-in keyword map (or a fallback) was used.
///   The caller looks up the id for that name in the categories table.
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

  /// Fallback for an expense.
  static const String fallback = 'Others';

  /// Fallback for income (the default income category).
  static const String incomeFallback = 'Money received';

  /// Keyword → default expense category (names match PLAN.md rule 11).
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
    'harithamithram': 'Bills',
    'netflix': 'Entertainment',
    'hotstar': 'Entertainment',
    'spotify': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'apollo': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
    'puc': 'Vehicle',
    'vaahan': 'Vehicle',
    'rto': 'Vehicle',
    'fastag': 'Vehicle',
    'petrol': 'Vehicle',
    'fuel': 'Vehicle',
    'challan': 'Tax & Govt',
    'income tax': 'Tax & Govt',
    'itd': 'Tax & Govt',
    'gst': 'Tax & Govt',
    'lsgd': 'Tax & Govt',
    'panchayat': 'Tax & Govt',
    'municipality': 'Tax & Govt',
  };

  static final RegExp _refund = RegExp(r'\brefund', caseSensitive: false);
  static final RegExp _cashback = RegExp(r'\bcashback\b', caseSensitive: false);
  // "salary" in any case, or "SAL" in capitals only (so "sale" doesn't count).
  static final RegExp _salaryWord = RegExp(r'\bsalary\b', caseSensitive: false);
  static final RegExp _salUpper = RegExp(r'\bSAL\b');

  /// Full guess for a parsed SMS:
  /// - income: Refund / Cashback / Salary (only if the text says salary or
  ///   SAL), then learned rules, else 'Money received';
  /// - expense: learned rules, keyword map on the merchant, and for receipts
  ///   (where the merchant is often a sender code like "Itdcpc") the keyword
  ///   map on the SMS text too; else 'Others'.
  static CategoryGuess guessSms(ParsedSms sms, List<MerchantRule> rules) {
    final name = sms.merchant.toLowerCase();

    if (sms.type == 'income') {
      if (_refund.hasMatch(sms.body)) {
        return const CategoryGuess.fromName('Refund');
      }
      if (_cashback.hasMatch(sms.body)) {
        return const CategoryGuess.fromName('Cashback');
      }
      if (_isSalary(sms.body)) return const CategoryGuess.fromName('Salary');
      return _fromRules(name, rules) ??
          const CategoryGuess.fromName(incomeFallback);
    }

    return _fromRules(name, rules) ??
        _fromKeywords(name) ??
        (sms.kind == 'receipt'
            ? _fromKeywords(sms.body.toLowerCase())
            : null) ??
        const CategoryGuess.fromName(fallback);
  }

  /// Merchant-only guess (rules → keyword map → 'Others'). Used by
  /// sms_service until step 6b switches it to [guessSms].
  static CategoryGuess guess(String merchant, List<MerchantRule> rules) {
    final name = merchant.toLowerCase();
    return _fromRules(name, rules) ??
        _fromKeywords(name) ??
        const CategoryGuess.fromName(fallback);
  }

  static bool _isSalary(String body) =>
      _salaryWord.hasMatch(body) || _salUpper.hasMatch(body);

  /// Learned rules first; the longest matching keyword wins.
  static CategoryGuess? _fromRules(String name, List<MerchantRule> rules) {
    final sorted = [...rules]
      ..sort((a, b) => b.keyword.length.compareTo(a.keyword.length));
    for (final rule in sorted) {
      final keyword = rule.keyword.trim().toLowerCase();
      if (keyword.isNotEmpty && _matches(name, keyword)) {
        return CategoryGuess.fromRule(rule.categoryId);
      }
    }
    return null;
  }

  static CategoryGuess? _fromKeywords(String text) {
    for (final entry in keywordMap.entries) {
      if (_matches(text, entry.key)) return CategoryGuess.fromName(entry.value);
    }
    return null;
  }

  /// Short keywords (3 letters or fewer, like 'vi', 'ola', 'itd') must be a
  /// whole word, so "Ravi" is not Bills and "Motorola" is not Travel.
  /// Longer keywords may appear inside a word ("Swiggyinstamart").
  static bool _matches(String text, String keyword) {
    if (keyword.length > 3) return text.contains(keyword);
    return RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(text);
  }
}
