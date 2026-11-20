/// One row of the `detected_sms` table: a bank SMS parsed into a suggestion.
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
  });

  bool get isPending => status == 'pending';

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
      );

  DetectedSms copyWith({
    int? id,
    String? merchant,
    String? paymentMode,
    int? guessedCategoryId,
    String? status,
  }) =>
      DetectedSms(
        id: id ?? this.id,
        sender: sender,
        body: body,
        amountPaise: amountPaise,
        type: type,
        merchant: merchant ?? this.merchant,
        accountLast4: accountLast4,
        paymentMode: paymentMode ?? this.paymentMode,
        guessedCategoryId: guessedCategoryId ?? this.guessedCategoryId,
        receivedAt: receivedAt,
        status: status ?? this.status,
      );

  @override
  String toString() =>
      'DetectedSms($id, $sender, $type, $amountPaise paise, $merchant, $status)';
}
