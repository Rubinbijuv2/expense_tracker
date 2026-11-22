/// One row of the `merchant_rules` table: "SMS from this merchant → this category".
class MerchantRule {
  final int? id;
  final String keyword; // stored lowercase, e.g. 'swiggy'
  final int categoryId;

  const MerchantRule({
    this.id,
    required this.keyword,
    required this.categoryId,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'keyword': keyword.trim().toLowerCase(),
    'category_id': categoryId,
  };

  factory MerchantRule.fromMap(Map<String, Object?> map) => MerchantRule(
    id: map['id'] as int?,
    keyword: map['keyword'] as String,
    categoryId: map['category_id'] as int,
  );

  @override
  String toString() => 'MerchantRule($id, $keyword → $categoryId)';
}
