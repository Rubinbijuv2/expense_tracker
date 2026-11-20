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
