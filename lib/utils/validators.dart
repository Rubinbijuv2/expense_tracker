import 'formatters.dart';

/// Form checks for the Add/Edit screen. Each returns an error message to show
/// under the field, or null when the value is fine (that is what Flutter's
/// `validator:` expects).

/// Amount is required, must be a valid number with at most 2 decimals, and > 0.
String? validateAmount(String? text) {
  if (text == null || text.trim().isEmpty) return 'Enter an amount';
  final paise = parseToPaise(text);
  if (paise == null) return 'Enter a valid amount, e.g. 250 or 99.50';
  if (paise <= 0) return 'Amount must be more than ₹0';
  return null;
}

/// A category must be picked.
String? validateCategory(int? categoryId) =>
    categoryId == null ? 'Pick a category' : null;

/// "My accounts": exactly the last 4 digits of an account or card number.
String? validateLast4(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return 'Enter the last 4 digits';
  if (!RegExp(r'^\d{4}$').hasMatch(t)) return 'Use exactly 4 digits, e.g. 1234';
  return null;
}
