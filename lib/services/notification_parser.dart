/// Turns a payment app notification (Google Pay, PhonePe, …) into a
/// [ParsedSms], like sms_parser does for bank SMS (PLAN.md section 7.4).
///
/// Pure Dart: no Flutter imports, so it runs in `flutter test` without a phone.
library;

import 'sms_parser.dart';

class NotificationParser {
  NotificationParser._(); // Only static methods.

  /// PLAN.md 7.3: the ONLY apps whose notifications are read. Every other
  /// app is dropped at the first step (the Kotlin service also checks this
  /// list, so other apps' notifications never even reach Dart).
  static const Map<String, String> allowedApps = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.dreamplug.androidapp': 'CRED',
    'in.amazon.mShop.android.shopping': 'Amazon',
  };

  /// "Google Pay" for its package name, or null if not allow-listed.
  static String? appName(String packageName) => allowedApps[packageName];

  // ---- Patterns -----------------------------------------------------------

  /// "₹1,000" / "Rs. 450.50" / "INR 80". Named group `amt`.
  static const String _amt =
      r'(?:₹|Rs\.?|INR)\s?(?<amt>\d[\d,]*(?:\.\d{1,2})?)';

  /// Money coming in. Named group `name` = who paid.
  static final List<RegExp> _incomePatterns = [
    // "Rahul Menon paid you ₹500" / "Anu sent you ₹500"
    RegExp(
      r'^(?<name>.+?)\s+(?:has\s+)?(?:paid|sent)\s+you\s+' + _amt,
      caseSensitive: false,
    ),
    // "Received ₹500 from Rahul"
    RegExp(
      r'received\s+' + _amt + r'\s+from\s+(?<name>.+)',
      caseSensitive: false,
    ),
    // "₹500 received from Rahul"
    RegExp(
      _amt + r'\s+(?:has\s+been\s+)?received\s+from\s+(?<name>.+)',
      caseSensitive: false,
    ),
  ];

  /// Money going out. Named group `name` = who was paid.
  static final List<RegExp> _expensePatterns = [
    // "Payment of ₹450 to Swiggy successful"
    RegExp(
      r'payment\s+of\s+' +
          _amt +
          r'\s+to\s+(?<name>.+?)\s+(?:was\s+|is\s+)?successful',
      caseSensitive: false,
    ),
    // "Paid ₹450 to Swiggy" / "You paid ₹450 to Swiggy"
    RegExp(r'paid\s+' + _amt + r'\s+to\s+(?<name>.+)', caseSensitive: false),
    // "Sent ₹80 to Rapido"
    RegExp(r'sent\s+' + _amt + r'\s+to\s+(?<name>.+)', caseSensitive: false),
    // "₹450 paid to Swiggy" / "₹80 sent to rapido@ybl"
    RegExp(
      _amt + r'\s+(?:paid|sent)\s+(?:successfully\s+)?to\s+(?<name>.+)',
      caseSensitive: false,
    ),
  ];

  /// PLAN.md 7.4 "Ignore": checked first, in this order, on all the text.
  /// The value is the reason shown on the developer Test screen.
  static final Map<RegExp, String> ignoreRules = {
    RegExp(
      r'\botp\b|verification code|one time password',
      caseSensitive: false,
    ): 'OTP',
    // Payment requests are NOT payments.
    RegExp(r'\brequest(?:ed|ing|s)?\b', caseSensitive: false):
        'payment request',
    RegExp(
      r'\b(?:failed|declined|unsuccessful|could not be completed)\b',
      caseSensitive: false,
    ): 'failed',
    RegExp(r'\b(?:pending|processing)\b', caseSensitive: false): 'pending',
    RegExp(
      r'\bremind(?:er)?\b|\bis due\b|\bdue (?:on|date|today|tomorrow)\b|'
      r'\boverdue\b|\bpay (?:before|by)\b',
      caseSensitive: false,
    ): 'bill reminder',
    RegExp(
      r'\boffers?\b|\bget\s+(?:₹|rs\.?|inr)|\bdiscount|\bflat\s+\d|'
      r'\bapply now\b|\bpre-?approved\b|\bearn\b|\bdeals?\b',
      caseSensitive: false,
    ): 'offer',
    RegExp(
      r'\bscratch|\brewards?\b|\bcashback\b|\bwon\b|\bwin\b|\bcoupons?\b|'
      r'\bvouchers?\b|\bcoins?\b|\bpoints?\b',
      caseSensitive: false,
    ): 'reward',
  };

  /// Where a name ends: "Uber India. UPI Ref …" → "Uber India".
  static final RegExp _nameStop = RegExp(
    r'\s+(?:on|via|using|from|for|is|was|has|successful(?:ly)?|ref|upi|txn|'
    r'transaction|at|with)\b|[.!|·,:;\n]|\s+-\s',
    caseSensitive: false,
  );

  /// "rapido@ybl" → "rapido", "rahul.k@okaxis" → "rahul.k".
  static final RegExp _upiId = RegExp(r'^([\w.\-]+)@[a-zA-Z]+');
  static final RegExp _spaces = RegExp(r'\s+');

  // ---- Parsing ------------------------------------------------------------

  static ParsedSms? parse(
    String packageName,
    String? title,
    String? text, {
    String? bigText,
    Set<String> ignoredApps = const {},
  }) => parseWithReason(
    packageName,
    title,
    text,
    bigText: bigText,
    ignoredApps: ignoredApps,
  ).sms;

  /// Same as [parse], but says why a notification was ignored.
  ///
  /// [ignoredApps] = app names the user chose "Always ignore" for
  /// (stored in capitals in ignored_senders, e.g. "GOOGLE PAY").
  static ParseResult parseWithReason(
    String packageName,
    String? title,
    String? text, {
    String? bigText,
    Set<String> ignoredApps = const {},
  }) {
    final app = allowedApps[packageName];
    if (app == null) {
      return const ParseResult.ignored('not an allow-listed payment app');
    }
    if (ignoredApps.any((s) => s.trim().toUpperCase() == app.toUpperCase())) {
      return const ParseResult.ignored('app is on your ignore list');
    }

    final parts = textParts(title, text, bigText);
    if (parts.isEmpty) return const ParseResult.ignored('empty notification');
    final all = parts.join(' · ');

    for (final rule in ignoreRules.entries) {
      if (rule.key.hasMatch(all)) return ParseResult.ignored(rule.value);
    }

    // Each part separately, so a name never runs into the next line.
    for (final part in parts) {
      final found =
          _firstMatch(_incomePatterns, part, 'income') ??
          _firstMatch(_expensePatterns, part, 'expense');
      if (found == null) continue;
      final (type, match) = found;
      final paise = SmsParser.rupeesToPaise(match.namedGroup('amt')!);
      if (paise == null || paise <= 0) {
        return const ParseResult.ignored('no amount found');
      }
      return ParseResult.parsed(
        ParsedSms(
          sender: app,
          body: parts.join('\n'),
          amountPaise: paise,
          type: type,
          merchant: cleanName(match.namedGroup('name')!),
          // Medium confidence, like a receipt SMS. Stored as 'receipt' so it
          // pairs with a bank SMS (rule 12 / section 7.5); the card shows
          // "App · Google Pay" because source = 'notification'.
          kind: 'receipt',
          paymentMode: 'UPI',
        ),
      );
    }
    return const ParseResult.ignored('not a payment notification');
  }

  /// Title, text and big text, trimmed, without empties or repeats. When
  /// the big text is a longer version of the text, only the big text is kept.
  static List<String> textParts(String? title, String? text, String? bigText) {
    String clean(String? s) => (s ?? '').replaceAll(_spaces, ' ').trim();
    final t = clean(title);
    var body = clean(text);
    final big = clean(bigText);
    if (big.isNotEmpty && (body.isEmpty || big.contains(body))) body = big;
    return [if (t.isNotEmpty) t, if (body.isNotEmpty && body != t) body];
  }

  static (String, RegExpMatch)? _firstMatch(
    List<RegExp> patterns,
    String text,
    String type,
  ) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return (type, m);
    }
    return null;
  }

  /// "rapido@ybl" → "Rapido", "UBER INDIA. UPI Ref 1" → "Uber India".
  static String cleanName(String raw) {
    var name = raw.trim();
    final upi = _upiId.firstMatch(name);
    if (upi != null) {
      name = upi.group(1)!.replaceAll(RegExp(r'[._\-]'), ' ');
    } else {
      final stop = _nameStop.firstMatch(name);
      if (stop != null) name = name.substring(0, stop.start);
    }
    name = name.trim();
    if (name.length > 40) name = name.substring(0, 40);
    final result = name
        .split(_spaces)
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
    return result.isEmpty ? 'Unknown' : result;
  }
}
