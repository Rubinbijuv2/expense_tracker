/// Spots money moved between the user's own accounts (PLAN.md rule 13).
///
/// Pure Dart: no Flutter imports, so it is unit-tested without a phone.
library;

class SelfTransfer {
  SelfTransfer._();

  /// "XX5678", "X678", "**5678" — masked account numbers. The look-behind
  /// `(?<![A-Za-z])` stops words like "MAX1234" from counting.
  static final RegExp _masked = RegExp(
    r'(?<![A-Za-z])(?:X+|\*+)(\d{3,4})\b',
    caseSensitive: false,
  );

  /// "A/c 5678", "Acct no. 5678", "Card ending 5678", "ending with 5678".
  static final RegExp _named = RegExp(
    r'\b(?:A/?c|Acct|Account|Card)\b(?:\s*no\.?)?\s*'
    r'(?:ending\s*(?:with\s*)?)?(\d{3,4})\b|'
    r'\bending\s*(?:with\s*)?(\d{3,4})\b',
    caseSensitive: false,
  );

  /// "trf to SELF", "to self". Not "self-service".
  static final RegExp _selfWord = RegExp(
    r'\bself\b(?!-)',
    caseSensitive: false,
  );

  /// True if the SMS is a transfer to/from one of the user's own accounts.
  ///
  /// [accountLast4] is the account the bank SMS is about (the user's own
  /// account by definition), so it is skipped once; any OTHER account number
  /// in the text that matches [ownLast4] is the counterparty → self transfer.
  /// The word "self" alone is also enough.
  static bool detect(String body, String? accountLast4, Set<String> ownLast4) {
    if (_selfWord.hasMatch(body)) return true;
    if (ownLast4.isEmpty) return false;

    final found = accountNumbers(body);
    // Skip the SMS's own account once (it may legitimately appear again
    // only if the counterparty has the same digits, which we can't tell apart).
    if (accountLast4 != null) found.remove(accountLast4);
    return found.any((digits) => ownLast4.any((own) => _same(own, digits)));
  }

  /// Every masked / named account number in the text, in order.
  static List<String> accountNumbers(String body) {
    final hits = <(int, String)>[];
    for (final m in _masked.allMatches(body)) {
      hits.add((m.start, m.group(1)!));
    }
    for (final m in _named.allMatches(body)) {
      final digits = m.group(1) ?? m.group(2)!;
      // The same number may match both patterns ("A/c XX1234"); keep one.
      final dup = hits.any(
        (h) => h.$2 == digits && (h.$1 - m.start).abs() < 20,
      );
      if (!dup) hits.add((m.start, digits));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final h in hits) h.$2];
  }

  /// "5678" vs "678": SMS sometimes show only 3 digits.
  static bool _same(String own, String digits) =>
      own == digits || (digits.length == 3 && own.endsWith(digits));
}
