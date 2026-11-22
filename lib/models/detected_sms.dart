/// One row of the `detected_sms` table: a bank SMS (or, since v3, a payment
/// app notification) parsed into a suggestion.
class DetectedSms {
  final int? id;
  final String sender;
  final String body;
  final int amountPaise;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final String? accountLast4;
  final String? paymentMode;
  final int? guessedCategoryId;
  final DateTime receivedAt;
  final String status; // 'pending', 'saved' or 'ignored'
  final String kind; // 'bank' (high), 'receipt' (medium), 'check' (low)
  final bool isSelfTransfer; // between the user's own accounts (rule 13)
  final int? duplicateOf; // id of the other SMS of a Bank + Receipt pair
  final int? suggestedRecurringId; // used from build step 13
  final String source; // 'sms' or 'notification' (v3)
  final String? sourceApp; // 'Google Pay' etc. for notifications (v3)

  const DetectedSms({
    this.id,
    required this.sender,
    required this.body,
    required this.amountPaise,
    required this.type,
    this.merchant,
    this.accountLast4,
    this.paymentMode,
    this.guessedCategoryId,
    required this.receivedAt,
    this.status = 'pending',
    this.kind = 'check',
    this.isSelfTransfer = false,
    this.duplicateOf,
    this.suggestedRecurringId,
    this.source = 'sms',
    this.sourceApp,
  });

  bool get isPending => status == 'pending';

  /// Came from a payment app notification (PLAN.md section 7), not an SMS.
  bool get isNotification => source == 'notification';

  /// Text for the label on the card (rule 4). Notifications say
  /// "App · Google Pay" (section 7.4).
  String get kindLabel => isNotification
      ? 'App · ${sourceApp ?? sender}'
      : switch (kind) {
          'bank' => 'Bank',
          'receipt' => 'Receipt',
          _ => 'Check this',
        };

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'sender': sender,
    'body': body,
    'amount_paise': amountPaise,
    'type': type,
    'merchant': merchant,
    'account_last4': accountLast4,
    'payment_mode': paymentMode,
    'guessed_category_id': guessedCategoryId,
    'received_at': receivedAt.toIso8601String(),
    'status': status,
    'kind': kind,
    'is_self_transfer': isSelfTransfer ? 1 : 0,
    'duplicate_of': duplicateOf,
    'suggested_recurring_id': suggestedRecurringId,
    'source': source,
    'source_app': sourceApp,
  };

  factory DetectedSms.fromMap(Map<String, Object?> map) => DetectedSms(
    id: map['id'] as int?,
    sender: map['sender'] as String,
    body: map['body'] as String,
    amountPaise: map['amount_paise'] as int,
    type: map['type'] as String,
    merchant: map['merchant'] as String?,
    accountLast4: map['account_last4'] as String?,
    paymentMode: map['payment_mode'] as String?,
    guessedCategoryId: map['guessed_category_id'] as int?,
    receivedAt: DateTime.parse(map['received_at'] as String),
    status: map['status'] as String? ?? 'pending',
    kind: map['kind'] as String? ?? 'check',
    isSelfTransfer: (map['is_self_transfer'] as int? ?? 0) == 1,
    duplicateOf: map['duplicate_of'] as int?,
    suggestedRecurringId: map['suggested_recurring_id'] as int?,
    source: map['source'] as String? ?? 'sms',
    sourceApp: map['source_app'] as String?,
  );

  /// [clearDuplicateOf] sets duplicateOf back to null ("Not the same").
  DetectedSms copyWith({
    int? id,
    String? merchant,
    String? paymentMode,
    String? accountLast4,
    int? guessedCategoryId,
    String? status,
    bool? isSelfTransfer,
    int? duplicateOf,
    bool clearDuplicateOf = false,
    String? source,
    String? sourceApp,
  }) => DetectedSms(
    id: id ?? this.id,
    sender: sender,
    body: body,
    amountPaise: amountPaise,
    type: type,
    merchant: merchant ?? this.merchant,
    accountLast4: accountLast4 ?? this.accountLast4,
    paymentMode: paymentMode ?? this.paymentMode,
    guessedCategoryId: guessedCategoryId ?? this.guessedCategoryId,
    receivedAt: receivedAt,
    status: status ?? this.status,
    kind: kind,
    isSelfTransfer: isSelfTransfer ?? this.isSelfTransfer,
    duplicateOf: clearDuplicateOf ? null : (duplicateOf ?? this.duplicateOf),
    suggestedRecurringId: suggestedRecurringId,
    source: source ?? this.source,
    sourceApp: sourceApp ?? this.sourceApp,
  );

  @override
  String toString() =>
      'DetectedSms($id, $sender, $type, $amountPaise paise, $merchant, '
      '$kind, $status${isSelfTransfer ? ', self' : ''})';
}
