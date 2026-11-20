/// One row of the `budgets` table.
class Budget {
  final int? id;
  final String month; // 'YYYY-MM'
  final int? categoryId; // null = overall monthly budget
  final int limitPaise;
  final bool alert80Sent;
  final bool alert100Sent;

  const Budget({
    this.id,
    required this.month,
    this.categoryId,
    required this.limitPaise,
    this.alert80Sent = false,
    this.alert100Sent = false,
  });

  bool get isOverall => categoryId == null;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'month': month,
        'category_id': categoryId,
        'limit_paise': limitPaise,
        'alert_80_sent': alert80Sent ? 1 : 0,
        'alert_100_sent': alert100Sent ? 1 : 0,
      };

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        id: map['id'] as int?,
        month: map['month'] as String,
        categoryId: map['category_id'] as int?,
        limitPaise: map['limit_paise'] as int,
        alert80Sent: (map['alert_80_sent'] as int? ?? 0) == 1,
        alert100Sent: (map['alert_100_sent'] as int? ?? 0) == 1,
      );

  Budget copyWith({
    int? id,
    String? month,
    int? limitPaise,
    bool? alert80Sent,
    bool? alert100Sent,
  }) =>
      Budget(
        id: id ?? this.id,
        month: month ?? this.month,
        categoryId: categoryId,
        limitPaise: limitPaise ?? this.limitPaise,
        alert80Sent: alert80Sent ?? this.alert80Sent,
        alert100Sent: alert100Sent ?? this.alert100Sent,
      );

  @override
  String toString() => 'Budget($id, $month, cat $categoryId, $limitPaise paise)';
}
