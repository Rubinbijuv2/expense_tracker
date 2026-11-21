import 'package:intl/intl.dart';

/// Money and date helpers. Money is always kept as int paise (₹1 = 100 paise)
/// and only turned into text here, for display.

// 'en_IN' gives Indian grouping: 1,23,45,678.90
final NumberFormat _rupees =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// 123450 → "₹1,234.50", 12345678 → "₹1,23,456.78", -50000 → "-₹500.00".
String formatPaise(int paise) {
  // Format rupees and paise separately so no decimal (double) rounding happens.
  final negative = paise < 0;
  final abs = paise.abs();
  final rupeesPart = _rupees.format(abs ~/ 100); // e.g. "₹1,234.00"
  final whole = rupeesPart.substring(0, rupeesPart.length - 3); // "₹1,234"
  final paisePart = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$paisePart';
}

/// Plain number for a text field when editing: 123450 → "1234.50", 50000 → "500".
String paiseToInput(int paise) {
  final rupees = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 ? '$rupees' : '$rupees.${rest.toString().padLeft(2, '0')}';
}

// Digits, optionally followed by a dot and 1–2 digits. Max 13 rupee digits
// (₹99 lakh crore) so the int never overflows.
final RegExp _amountPattern = RegExp(r'^(\d{1,13})(?:\.(\d{1,2}))?$');
final RegExp _prefixPattern = RegExp(r'^(?:₹|rs\.?|inr)', caseSensitive: false);

/// Turns typed or formatted text into paise, or null if it is not a valid amount.
///
/// "₹1,234.50" → 123450, "1234.5" → 123450, "Rs. 500" → 50000, "0" → 0.
/// null for: "", "abc", "12.345" (3 decimals), "-5", "1.2.3".
/// Note: 0 is valid here — validators.dart decides that an amount must be > 0.
int? parseToPaise(String? text) {
  if (text == null) return null;
  var s = text.trim().replaceFirst(_prefixPattern, '');
  s = s.replaceAll(',', '').replaceAll(' ', '');
  final match = _amountPattern.firstMatch(s);
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final decimals = (match.group(2) ?? '').padRight(2, '0'); // "5" → "50"
  return rupees * 100 + int.parse(decimals);
}

/// DateTime → 'YYYY-MM', the month key used by the budgets table.
String monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);

// Short Indian-style amounts for chart axes, without decimals.
final NumberFormat _compactRupees =
    NumberFormat.compactSimpleCurrency(locale: 'en_IN', name: 'INR');

/// Short label for chart axes: 120000 paise → "₹1.2K", 25000000 → "₹2.5L".
String formatPaiseCompact(int paise) =>
    paise == 0 ? '₹0' : _compactRupees.format(paise / 100);
