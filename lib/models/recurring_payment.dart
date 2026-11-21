/// One row of the `recurring_payments` table: a bill, subscription, EMI,
/// chitti or class fee that repeats (PLAN.md section 5).
class RecurringPayment {
  final int? id;
  final String name;
  final String type; // 'bill', 'emi', 'chitti' or 'fee'
  final int amountPaise; // usual amount for one installment
  final int categoryId;
  final String frequency; // 'monthly', 'weekly' or 'yearly'

  /// monthly / yearly: day of the month (1–31, the 31st becomes the last day
  /// in short months). weekly: weekday, 1 = Monday … 7 = Sunday.
  final int dueDay;
  final DateTime startDate; // date only; yearly items use its month
  final DateTime? endDate; // bills and fees: optional last date
  final int? totalInstallments; // EMI months / chitti months
  final int remindDaysBefore;
  final String paymentMode;
  final String? matchKeyword; // e.g. "HDFC LOAN" (SMS matching, step 13)
  final String? organiserName; // chitti only
  final String? organiserPhone; // chitti only
  final int? chittiReceivedPaise; // lump sum received, chitti only
  final DateTime? chittiReceivedDate;
  final String? notes;
  final bool active;
  final DateTime createdAt;

  RecurringPayment({
    this.id,
    required this.name,
    required this.type,
    required this.amountPaise,
    required this.categoryId,
    this.frequency = 'monthly',
    required this.dueDay,
    required this.startDate,
    this.endDate,
    this.totalInstallments,
    this.remindDaysBefore = 1,
    required this.paymentMode,
    this.matchKeyword,
    this.organiserName,
    this.organiserPhone,
    this.chittiReceivedPaise,
    this.chittiReceivedDate,
    this.notes,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static const List<String> types = ['bill', 'emi', 'chitti', 'fee'];

  /// Label shown on the type selector and as group headings.
  static String typeLabel(String type) => switch (type) {
    'bill' => 'Bill / Subscription',
    'emi' => 'EMI / Loan',
    'chitti' => 'Chitti',
    _ => 'Class / Fee',
  };

  /// Default category name for each type (must match default_categories.dart).
  static String defaultCategoryName(String type) => switch (type) {
    'bill' => 'Bills',
    'emi' => 'Loan & EMI',
    'chitti' => 'Chitti',
    _ => 'Fees & Classes',
  };

  bool get isChitti => type == 'chitti';
  bool get isEmi => type == 'emi';

  /// EMI and chitti have a fixed number of months, so they show progress.
  bool get hasProgress => (isEmi || isChitti) && totalInstallments != null;
  bool get chittiReceived => chittiReceivedPaise != null;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'amount_paise': amountPaise,
    'category_id': categoryId,
    'frequency': frequency,
    'due_day': dueDay,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'total_installments': totalInstallments,
    'remind_days_before': remindDaysBefore,
    'payment_mode': paymentMode,
    'match_keyword': matchKeyword,
    'organiser_name': organiserName,
    'organiser_phone': organiserPhone,
    'chitti_received_paise': chittiReceivedPaise,
    'chitti_received_date': chittiReceivedDate?.toIso8601String(),
    'notes': notes,
    'active': active ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory RecurringPayment.fromMap(Map<String, Object?> map) =>
      RecurringPayment(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        amountPaise: map['amount_paise'] as int,
        categoryId: map['category_id'] as int,
        frequency: map['frequency'] as String? ?? 'monthly',
        dueDay: map['due_day'] as int,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: _date(map['end_date']),
        totalInstallments: map['total_installments'] as int?,
        remindDaysBefore: map['remind_days_before'] as int? ?? 1,
        paymentMode: map['payment_mode'] as String,
        matchKeyword: map['match_keyword'] as String?,
        organiserName: map['organiser_name'] as String?,
        organiserPhone: map['organiser_phone'] as String?,
        chittiReceivedPaise: map['chitti_received_paise'] as int?,
        chittiReceivedDate: _date(map['chitti_received_date']),
        notes: map['notes'] as String?,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  @override
  String toString() => 'RecurringPayment($id, $name, $type, $amountPaise)';
}
