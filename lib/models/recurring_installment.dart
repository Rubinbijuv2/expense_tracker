/// One row of the `recurring_installments` table: a single due date of a
/// repeat payment and whether it was paid, skipped or is still pending.
class RecurringInstallment {
  final int? id;
  final int recurringId;
  final DateTime dueDate; // date only (midnight)
  final String status; // 'pending', 'paid' or 'skipped'
  final int? paidAmountPaise;
  final int? transactionId; // the expense created by "Mark as paid"
  final DateTime? paidAt;

  const RecurringInstallment({
    this.id,
    required this.recurringId,
    required this.dueDate,
    this.status = 'pending',
    this.paidAmountPaise,
    this.transactionId,
    this.paidAt,
  });

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isSkipped => status == 'skipped';

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'recurring_id': recurringId,
    'due_date': dueDate.toIso8601String(),
    'status': status,
    'paid_amount_paise': paidAmountPaise,
    'transaction_id': transactionId,
    'paid_at': paidAt?.toIso8601String(),
  };

  factory RecurringInstallment.fromMap(Map<String, Object?> map) =>
      RecurringInstallment(
        id: map['id'] as int?,
        recurringId: map['recurring_id'] as int,
        dueDate: DateTime.parse(map['due_date'] as String),
        status: map['status'] as String? ?? 'pending',
        paidAmountPaise: map['paid_amount_paise'] as int?,
        transactionId: map['transaction_id'] as int?,
        paidAt: map['paid_at'] == null
            ? null
            : DateTime.parse(map['paid_at'] as String),
      );

  /// Same installment marked as paid.
  RecurringInstallment paid(int amountPaise, int? txnId, DateTime at) =>
      RecurringInstallment(
        id: id,
        recurringId: recurringId,
        dueDate: dueDate,
        status: 'paid',
        paidAmountPaise: amountPaise,
        transactionId: txnId,
        paidAt: at,
      );

  /// Same installment with a new status and the payment details cleared
  /// (used for "Skip", "Mark as not paid" and "Undo skip").
  RecurringInstallment withStatus(String newStatus) => RecurringInstallment(
    id: id,
    recurringId: recurringId,
    dueDate: dueDate,
    status: newStatus,
  );

  @override
  String toString() => 'RecurringInstallment($id, $dueDate, $status)';
}
