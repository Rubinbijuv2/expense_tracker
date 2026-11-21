/// All regular expressions used by sms_parser.dart (PLAN.md section 4).
/// Kept in one place so each rule is easy to find and explain.
///
/// Pure Dart: no Flutter imports.
library;

class SmsRules {
  SmsRules._();

  static const _amt = r'(?:Rs\.?|INR|₹)\s*[\d,]+(?:\.\d{1,2})?';

  // ---- Rule 1: sender. Group 1 = name (HDFCBK), group 2 = TRAI letter ----
  static final RegExp bankSender = RegExp(
    r'^[A-Z]{2}-([A-Z0-9]{3,9})(?:-([PSTG]))?$',
  );

  // ---- Rule 2: money words (the first one found decides the type) ----
  static final RegExp txnWord = RegExp(
    r'\b(debited|credited|spent|paid|sent|withdrawn|received|purchase|'
    r'refund|refunded|deposited)\b',
    caseSensitive: false,
  );

  /// First money words that mean money came IN (everything else = expense).
  static const Set<String> incomeWords = {
    'credited',
    'received',
    'deposited',
    'refund',
    'refunded',
  };

  // ---- Rule 3: words that mean "not a real transaction" ----
  static const String promoReason = 'promotional message';

  static final Map<RegExp, String> dropWords = {
    RegExp(
      r'\botp\b|one time password|verification code',
      caseSensitive: false,
    ): 'OTP message',
    RegExp(
      r'\boffer|cashback on|apply now|loyalty points?|reward points?|'
      r'\bpoints\b|\bredeem|\bvoucher|\bcoins\b|\btnc apply|t&c apply',
      caseSensitive: false,
    ): promoReason,
    RegExp(r'will be debited', caseSensitive: false):
        'future debit (not paid yet)',
    RegExp(r'requested', caseSensitive: false):
        'payment request (not paid yet)',
    RegExp(r'has been processed', caseSensitive: false):
        'processing notice (money not moved yet)',
    RegExp(r'\bis due\b|due on|statement', caseSensitive: false):
        'bill statement or due reminder',
    RegExp(r'e-verified|intimation', caseSensitive: false):
        'information message',
  };

  // ---- Rule 4: kind ----
  /// A shop/office confirming your payment.
  static final RegExp receiptPhrase = RegExp(
    'payment of $_amt.{0,80}?\\breceived\\b|payment received for|'
    r'successfully paid|paid successfully|receipt no',
    caseSensitive: false,
  );

  /// An account is named: "A/c", "Acct", "XX1234", "**1234".
  static final RegExp accountMention = RegExp(
    r'\b(?:A/?c|Acct|Account)\b|(?:XX|\*\*)\d{3,4}',
    caseSensitive: false,
  );

  /// A UPI/bank reference without an account number.
  static final RegExp upiReference = RegExp(
    r'\b(?:UPI|VPA)\b|\bRef\.?\s?No\b',
    caseSensitive: false,
  );

  // ---- Rule 5: direction ----
  static final RegExp refundWord = RegExp(r'\brefund', caseSensitive: false);

  static final RegExp cashbackCredited = RegExp(
    'cashback of $_amt.{0,60}?\\bcredited\\b',
    caseSensitive: false,
  );

  /// Bank wording that means money came in. "(?:(?!debited)[^.;])" = any
  /// character except . or ; as long as "debited" does not start there.
  static final RegExp incomeWording = RegExp(
    r'your a/?c(?:count)?\b(?:(?!debited)[^.;]){0,40}\bcredited|'
    r'credited to (?:your )?(?:a/?c|acct|account)|'
    r'credited by\s*(?:Rs\.?|INR|₹)|'
    r'received in your (?:a/?c|acct|account)|'
    r'\bdeposited\b',
    caseSensitive: false,
  );

  // ---- Rule 6: amount ----
  static final RegExp amount = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp amountSbiStyle = RegExp(
    r'(?:debited|credited) by\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // ---- Rule 7: merchant ----
  static final RegExp nameThenCredited = RegExp(
    r';\s*([^;.]+?)\s+credited',
    caseSensitive: false,
  );
  static final RegExp expenseLead = RegExp(
    r'\b(?:trf\s+to|towards|to|at|VPA)\s+(?:VPA\s+)?(.+)',
    caseSensitive: false,
  );
  static final RegExp incomeLead = RegExp(
    r'\bfrom\s+(.+)',
    caseSensitive: false,
  );
  static final RegExp merchantStop = RegExp(
    r'\s+(?:on|from|refno|ref|upi|avl|via|credited|debited)\b'
    r'|\.(?=\s|$)|[(;,:]',
    caseSensitive: false,
  );

  /// Receipt: "payment of Rs 50.00 for Harithamithram is received".
  static final RegExp receiptFor = RegExp(
    'payment of $_amt\\s+for\\s+(.+)',
    caseSensitive: false,
  );
  static final RegExp receiptNameStop = RegExp(
    r'\s+(?:is|has|was|have|received|on|ref|receipt|via|vide|towards|'
    r'from|dated)\b|\.(?=\s|$)|[(;,:]',
    caseSensitive: false,
  );

  /// Short words kept in capitals when title-casing a merchant.
  static const Set<String> keepUpper = {'ATM'};

  // ---- Rule 8: account last digits ----
  static final RegExp account = RegExp(
    r'\b(?:A/?c(?:count)?|Acct|Card)\b[^\d]{0,12}?(?:XX|\*+)?(\d{3,4})',
    caseSensitive: false,
  );

  // ---- Rule 9: payment mode ----
  static final RegExp cashWord = RegExp(
    r'\b(?:ATM|withdrawn)\b',
    caseSensitive: false,
  );
  static final RegExp upiWord = RegExp(
    r'\b(?:UPI|VPA)\b',
    caseSensitive: false,
  );
  static final RegExp cardWord = RegExp(r'\bcard\b', caseSensitive: false);
  static final RegExp netBankingWord = RegExp(
    r'\b(?:NEFT|IMPS|RTGS)\b',
    caseSensitive: false,
  );

  static final RegExp spaces = RegExp(r'\s+');
}
