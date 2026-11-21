/// Turns a bank/UPI/receipt SMS into a [ParsedSms] (PLAN.md section 4,
/// rules 1–9). The regexes live in sms_rules.dart.
///
/// Pure Dart: no Flutter imports, so it runs in `flutter test` without a phone.
library;

import 'sms_rules.dart';

/// The facts pulled out of one SMS. Not a database row: sms_service turns
/// this into a `DetectedSms` once it knows when the SMS arrived.
class ParsedSms {
  final String sender;
  final String body;
  final int amountPaise;
  final String type; // 'expense' or 'income'
  final String merchant; // Title Case, or 'Unknown'
  final String? accountLast4;
  final String? paymentMode; // 'Cash', 'UPI', 'Card', 'Net banking' or null
  final String kind; // 'bank' (high), 'receipt' (medium), 'check' (low)

  const ParsedSms({
    required this.sender,
    required this.body,
    required this.amountPaise,
    required this.type,
    required this.merchant,
    required this.kind,
    this.accountLast4,
    this.paymentMode,
  });

  @override
  String toString() =>
      'ParsedSms($amountPaise paise, $type, $merchant, '
      'mode $paymentMode, a/c $accountLast4, kind $kind)';
}

/// Either a [ParsedSms], or the reason the SMS was ignored.
class ParseResult {
  final ParsedSms? sms;
  final String? ignoredReason;

  const ParseResult.parsed(ParsedSms this.sms) : ignoredReason = null;
  const ParseResult.ignored(String this.ignoredReason) : sms = null;
}

class SmsParser {
  SmsParser._(); // Only static methods; not meant to be instantiated.

  /// Returns the parsed SMS, or null if it should be ignored.
  /// [ignoredSenders] = senders the user chose "Always ignore" for.
  static ParsedSms? parse(
    String sender,
    String body, {
    Set<String> ignoredSenders = const {},
  }) => parseWithReason(sender, body, ignoredSenders: ignoredSenders).sms;

  /// Same rules as [parse], but when the SMS is ignored it also says why
  /// (shown on the developer Test SMS screen).
  static ParseResult parseWithReason(
    String sender,
    String body, {
    Set<String> ignoredSenders = const {},
  }) {
    // ---- Rule 1: sender filter ----
    final from = sender.trim().toUpperCase();
    final senderMatch = SmsRules.bankSender.firstMatch(from);
    if (senderMatch == null) {
      return const ParseResult.ignored('not a bank sender');
    }
    if (senderMatch.group(2) == 'P') {
      return const ParseResult.ignored('promotional sender (-P)');
    }
    if (ignoredSenders.any((s) => s.trim().toUpperCase() == from)) {
      return const ParseResult.ignored('sender is on your ignore list');
    }

    final text = body.replaceAll(SmsRules.spaces, ' ').trim();

    // ---- Rule 3: drop words (checked first so an OTP says "OTP message") ----
    // "Cashback of Rs 25 credited to your a/c" is real money, so it skips
    // the promotional words (it may say "offer") but not the others.
    final realCashback = SmsRules.cashbackCredited.hasMatch(text);
    for (final drop in SmsRules.dropWords.entries) {
      if (realCashback && drop.value == SmsRules.promoReason) continue;
      if (drop.key.hasMatch(text)) return ParseResult.ignored(drop.value);
    }

    // ---- Rule 2: must have a money word ----
    final firstWord = SmsRules.txnWord.firstMatch(text);
    if (firstWord == null) {
      return const ParseResult.ignored('no transaction word (debited, paid…)');
    }

    // ---- Rule 6: amount ----
    final amountPaise = _findAmountPaise(text);
    if (amountPaise == null || amountPaise <= 0) {
      return const ParseResult.ignored('no amount found');
    }

    final kind = _findKind(text); // Rule 4
    final type = _findType(text, kind, firstWord.group(1)!); // Rule 5
    final mode = _findPaymentMode(text); // Rule 9

    return ParseResult.parsed(
      ParsedSms(
        sender: from,
        body: body.trim(),
        amountPaise: amountPaise,
        type: type,
        kind: kind,
        merchant: kind == 'receipt'
            ? _findReceiptMerchant(text, senderMatch.group(1)!)
            : _findMerchant(text, type), // Rule 7
        accountLast4: SmsRules.account.firstMatch(text)?.group(1), // Rule 8
        paymentMode: mode ?? (kind == 'receipt' ? 'Cash' : null),
      ),
    );
  }

  /// Rule 4. A receipt is a shop/office confirming YOUR payment. If the SMS
  /// also names an account ("A/c XX1234") it is the bank's own SMS → bank.
  static String _findKind(String text) {
    final hasAccount = SmsRules.accountMention.hasMatch(text);
    if (SmsRules.receiptPhrase.hasMatch(text) && !hasAccount) return 'receipt';
    if (hasAccount || SmsRules.upiReference.hasMatch(text)) return 'bank';
    return 'check';
  }

  /// Rule 5, checked in this order.
  static String _findType(String text, String kind, String firstWord) {
    if (kind == 'receipt') return 'expense'; // "payment received" = shop got it
    if (SmsRules.refundWord.hasMatch(text)) return 'income';
    if (SmsRules.cashbackCredited.hasMatch(text)) return 'income';
    if (SmsRules.incomeWording.hasMatch(text)) return 'income';
    // Otherwise the first money word decides.
    return SmsRules.incomeWords.contains(firstWord.toLowerCase())
        ? 'income'
        : 'expense';
  }

  static int? _findAmountPaise(String text) {
    final match =
        SmsRules.amount.firstMatch(text) ??
        SmsRules.amountSbiStyle.firstMatch(text);
    return match == null ? null : rupeesToPaise(match.group(1)!);
  }

  /// "1,299.5" → 129950. Uses whole numbers only, so no double rounding.
  static int? rupeesToPaise(String raw) {
    final parts = raw.replaceAll(',', '').split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;
    final paise = parts.length > 1
        ? int.tryParse(parts[1].padRight(2, '0')) ?? 0
        : 0;
    return rupees * 100 + paise;
  }

  /// Rule 7 for bank / check SMS.
  static String _findMerchant(String text, String type) {
    String? raw;
    if (type == 'expense') {
      raw =
          SmsRules.nameThenCredited.firstMatch(text)?.group(1) ??
          SmsRules.expenseLead.firstMatch(text)?.group(1);
    } else {
      raw = SmsRules.incomeLead.firstMatch(text)?.group(1);
    }
    return raw == null ? 'Unknown' : _cleanName(raw, SmsRules.merchantStop);
  }

  /// Rule 7 for receipts: "payment of Rs 50 for Harithamithram" → the name
  /// after "for"; otherwise the middle of the sender (AD-VAAHAN-S → Vaahan).
  static String _findReceiptMerchant(String text, String senderMiddle) {
    final raw = SmsRules.receiptFor.firstMatch(text)?.group(1);
    if (raw != null) {
      final name = _cleanName(raw, SmsRules.receiptNameStop);
      if (name != 'Unknown') return name;
    }
    return _titleCase(senderMiddle);
  }

  /// Cuts at the first stop word, turns a UPI ID into a name, title-cases.
  static String _cleanName(String raw, RegExp stopAt) {
    final stop = stopAt.firstMatch(raw);
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
      .split(SmsRules.spaces)
      .where((w) => w.isNotEmpty)
      .map(
        (w) => SmsRules.keepUpper.contains(w.toUpperCase())
            ? w.toUpperCase()
            : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');

  static String? _findPaymentMode(String text) {
    // Cash is checked first so "Card XX12 withdrawn at ATM" counts as Cash.
    if (SmsRules.cashWord.hasMatch(text)) return 'Cash';
    if (SmsRules.upiWord.hasMatch(text)) return 'UPI';
    if (SmsRules.cardWord.hasMatch(text)) return 'Card';
    if (SmsRules.netBankingWord.hasMatch(text)) return 'Net banking';
    return null;
  }
}
