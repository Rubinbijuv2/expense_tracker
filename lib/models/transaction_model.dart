/// One row of the `transactions` table.
///
/// Called TransactionModel because sqflite already has a class named `Transaction`.
class TransactionModel {
  final int? id;
  final int amountPaise; // always > 0; `type` says if it is money out or in
  final String type; // 'expense' or 'income'
  final int categoryId;
  final String paymentMode; // 'Cash', 'UPI', 'Card' or 'Net banking'
  final DateTime dateTime; // stored as ISO-8601 local time
  final String? note;
  final String? merchant;
  final String source; // 'manual' or 'sms'
  final int? smsId; // detected_sms.id when created from an SMS
  final DateTime createdAt;
  final int? recurringId; // recurring_payments.id (build step 12)
  final int? refundOfId; // the expense this refund belongs to (step 14)
  final bool isSelfTransfer; // own-account transfer: never counted in totals

  TransactionModel({
    this.id,
    required this.amountPaise,
    required this.type,
    required this.categoryId,
    required this.paymentMode,
    required this.dateTime,
    this.note,
    this.merchant,
    this.source = 'manual',
    this.smsId,
    DateTime? createdAt,
    this.recurringId,
    this.refundOfId,
    this.isSelfTransfer = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpense => type == 'expense';

  /// False for self transfers: every total, chart and budget skips them.
  bool get counts => !isSelfTransfer;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'amount_paise': amountPaise,
    'type': type,
    'category_id': categoryId,
    'payment_mode': paymentMode,
    'date_time': dateTime.toIso8601String(),
    'note': note,
    'merchant': merchant,
    'source': source,
    'sms_id': smsId,
    'created_at': createdAt.toIso8601String(),
    'recurring_id': recurringId,
    'refund_of_id': refundOfId,
    'is_self_transfer': isSelfTransfer ? 1 : 0,
  };

  factory TransactionModel.fromMap(Map<String, Object?> map) =>
      TransactionModel(
        id: map['id'] as int?,
        amountPaise: map['amount_paise'] as int,
        type: map['type'] as String,
        categoryId: map['category_id'] as int,
        paymentMode: map['payment_mode'] as String,
        dateTime: DateTime.parse(map['date_time'] as String),
        note: map['note'] as String?,
        merchant: map['merchant'] as String?,
        source: map['source'] as String? ?? 'manual',
        smsId: map['sms_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        recurringId: map['recurring_id'] as int?,
        refundOfId: map['refund_of_id'] as int?,
        isSelfTransfer: (map['is_self_transfer'] as int? ?? 0) == 1,
      );

  TransactionModel copyWith({
    int? id,
    int? amountPaise,
    String? type,
    int? categoryId,
    String? paymentMode,
    DateTime? dateTime,
    String? note,
    String? merchant,
    String? source,
    int? smsId,
    int? recurringId,
    bool? isSelfTransfer,
  }) => TransactionModel(
    id: id ?? this.id,
    amountPaise: amountPaise ?? this.amountPaise,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    paymentMode: paymentMode ?? this.paymentMode,
    dateTime: dateTime ?? this.dateTime,
    note: note ?? this.note,
    merchant: merchant ?? this.merchant,
    source: source ?? this.source,
    smsId: smsId ?? this.smsId,
    createdAt: createdAt,
    recurringId: recurringId ?? this.recurringId,
    refundOfId: refundOfId,
    isSelfTransfer: isSelfTransfer ?? this.isSelfTransfer,
  );

  @override
  String toString() =>
      'TransactionModel($id, $type, $amountPaise paise, cat $categoryId, '
      '$dateTime${isSelfTransfer ? ', self' : ''})';
}
