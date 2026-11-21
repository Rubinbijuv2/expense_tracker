/// Turns a bank/UPI SMS into a [ParsedSms] (PLAN.md section 4, rules 1–8).
///
/// Pure Dart: no Flutter imports, so it runs in `flutter test` without a phone.
library;

/// The facts pulled out of one bank SMS. Not a database row: step 6 turns
/// this into a `DetectedSms` once it knows when the SMS arrived.
class ParsedSms {
  final String sender;
  final String body;
  final int amountPaise;
  final String type; // 'expense' or 'income'
  final String merchant; // Title Case, or 'Unknown'
  final String? accountLast4;
  final String? paymentMode; // 'Cash', 'UPI', 'Card', 'Net banking' or null

  const ParsedSms({
    required this.sender,
    required this.body,
    required this.amountPaise,
    required this.type,
    required this.merchant,
    this.accountLast4,
    this.paymentMode,
  });

  @override
  String toString() => 'ParsedSms($amountPaise paise, $type, $merchant, '
      'mode $paymentMode, a/c $accountLast4)';
}

class SmsParser {
  SmsParser._(); // Only static methods; not meant to be instantiated.

  // ---- Rule 1: sender filter -------------------------------------------
  static final RegExp _bankSender =
      RegExp(r'^[A-Z]{2}-[A-Z0-9]{3,8}(?:-[A-Z])?$');

  // ---- Rules 2 & 5: transaction words (the first one decides the type) --
  static final RegExp _txnWord = RegExp(
    r'\b(debited|credited|spent|paid|sent|withdrawn|received|purchase)\b',
    caseSensitive: false,
  );

  // ---- Rule 3: words that mean "not a real transaction" -----------------
  static final RegExp _dropWord = RegExp(
    r'\botp\b|one time password|verification code|\boffer|cashback on'
    r'|apply now|due on|statement|will be debited|requested',
    caseSensitive: false,
  );

  // ---- Rule 4: amount ----------------------------------------------------
  static final RegExp _amount = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _amountSbiStyle = RegExp(
    r'(?:debited|credited) by\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // ---- Rule 6: merchant --------------------------------------------------
  static final RegExp _nameThenCredited =
      RegExp(r';\s*([^;.]+?)\s+credited', caseSensitive: false);
  static final RegExp _expenseLead = RegExp(
    r'\b(?:trf\s+to|towards|to|at|VPA)\s+(?:VPA\s+)?(.+)',
    caseSensitive: false,
  );
  static final RegExp _incomeLead =
      RegExp(r'\bfrom\s+(.+)', caseSensitive: false);
  static final RegExp _merchantStop = RegExp(
    r'\s+(?:on|from|refno|ref|upi|avl|via)\b|\.(?=\s|$)|[(;,:]',
    caseSensitive: false,
  );

  // ---- Rule 7: account last digits --------------------------------------
  static final RegExp _account = RegExp(
    r'\b(?:A/?c(?:count)?|Acct|Card)\b[^\d]{0,12}?(?:XX|\*+)?(\d{3,4})',
    caseSensitive: false,
  );

  // ---- Rule 8: payment mode ---------------------------------------------
  static final RegExp _cashWord =
      RegExp(r'\b(?:ATM|withdrawn)\b', caseSensitive: false);
  static final RegExp _upiWord =
      RegExp(r'\b(?:UPI|VPA)\b', caseSensitive: false);
  static final RegExp _cardWord = RegExp(r'\bcard\b', caseSensitive: false);
  static final RegExp _netBankingWord =
      RegExp(r'\b(?:NEFT|IMPS|RTGS)\b', caseSensitive: false);

  static final RegExp _spaces = RegExp(r'\s+');

  /// Short words kept in capitals when title-casing a merchant.
  static const Set<String> _keepUpper = {'ATM'};

  /// Returns the parsed SMS, or null if it should be ignored.
  static ParsedSms? parse(String sender, String body) {
    final from = sender.trim().toUpperCase();
    if (!_bankSender.hasMatch(from)) return null; // Rule 1

    final text = body.replaceAll(_spaces, ' ').trim();
    final firstWord = _txnWord.firstMatch(text);
    if (firstWord == null) return null; // Rule 2
    if (_dropWord.hasMatch(text)) return null; // Rule 3

    final amountPaise = _findAmountPaise(text); // Rule 4
    if (amountPaise == null || amountPaise <= 0) return null;

    final word = firstWord.group(1)!.toLowerCase(); // Rule 5
    final type =
        (word == 'credited' || word == 'received') ? 'income' : 'expense';

    return ParsedSms(
      sender: from,
      body: body.trim(),
      amountPaise: amountPaise,
      type: type,
      merchant: _findMerchant(text, type), // Rule 6
      accountLast4: _account.firstMatch(text)?.group(1), // Rule 7
      paymentMode: _findPaymentMode(text), // Rule 8
    );
  }

  static int? _findAmountPaise(String text) {
    final match = _amount.firstMatch(text) ?? _amountSbiStyle.firstMatch(text);
    return match == null ? null : rupeesToPaise(match.group(1)!);
  }

  /// "1,299.5" → 129950. Uses whole numbers only, so no double rounding.
  static int? rupeesToPaise(String raw) {
    final parts = raw.replaceAll(',', '').split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    final paise =
        parts.length > 1 ? int.tryParse(parts[1].padRight(2, '0')) ?? 0 : 0;
    return rupees * 100 + paise;
  }

  static String _findMerchant(String text, String type) {
    String? raw;
    if (type == 'expense') {
      raw = _nameThenCredited.firstMatch(text)?.group(1) ??
          _expenseLead.firstMatch(text)?.group(1);
    } else {
      raw = _incomeLead.firstMatch(text)?.group(1);
    }
    if (raw == null) return 'Unknown';

    // Cut at the first stop word / full stop, e.g. "UBER INDIA Refno 43…".
    final stop = _merchantStop.firstMatch(raw);
    var name = (stop == null ? raw : raw.substring(0, stop.start)).trim();

    // UPI ID: keep the part before '@'. "rahul.k@okaxis" → "rahul k".
    if (name.contains('@')) {
      name = name.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
    }
    if (name.length > 40) name = name.substring(0, 40);
    final result = _titleCase(name);
    return result.isEmpty ? 'Unknown' : result;
  }

  static String _titleCase(String input) => input
      .split(_spaces)
      .where((w) => w.isNotEmpty)
      .map((w) => _keepUpper.contains(w.toUpperCase())
          ? w.toUpperCase()
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  static String? _findPaymentMode(String text) {
    // Cash is checked first so "Card XX12 withdrawn at ATM" counts as Cash.
    if (_cashWord.hasMatch(text)) return 'Cash';
    if (_upiWord.hasMatch(text)) return 'UPI';
    if (_cardWord.hasMatch(text)) return 'Card';
    if (_netBankingWord.hasMatch(text)) return 'Net banking';
    return null;
  }
}
