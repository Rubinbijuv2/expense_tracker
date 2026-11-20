/// Total amount for one category in a month (one slice of the pie chart).
/// Not a table: it is built from a GROUP BY query in TransactionRepo.
class CategoryTotal {
  final int categoryId;
  final String name;
  final String icon;
  final int color;
  final int totalPaise;

  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.totalPaise,
  });

  factory CategoryTotal.fromMap(Map<String, Object?> map) => CategoryTotal(
        categoryId: map['category_id'] as int,
        name: map['name'] as String,
        icon: map['icon'] as String,
        color: map['color'] as int,
        totalPaise: map['total_paise'] as int? ?? 0,
      );

  @override
  String toString() => 'CategoryTotal($name, $totalPaise paise)';
}
