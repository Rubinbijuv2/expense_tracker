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
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpense => type == 'expense';

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
  }) =>
      TransactionModel(
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
      );

  @override
  String toString() =>
      'TransactionModel($id, $type, $amountPaise paise, cat $categoryId, $dateTime)';
}
