/// One row of the `categories` table.
///
/// Called CategoryModel because Flutter already has a class named `Category`.
class CategoryModel {
  final int? id; // null until the row is inserted
  final String name;
  final String icon; // key in utils/category_icons.dart, e.g. 'restaurant'
  final int color; // ARGB, e.g. 0xFFEF6C00 → use with Color(color)
  final String type; // 'expense' or 'income'
  final bool isDefault;

  const CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
  });

  bool get isIncome => type == 'income';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type,
        'is_default': isDefault ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, Object?> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        icon: map['icon'] as String,
        color: map['color'] as int,
        type: map['type'] as String,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
      );

  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    int? color,
    String? type,
    bool? isDefault,
  }) =>
      CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        type: type ?? this.type,
        isDefault: isDefault ?? this.isDefault,
      );

  @override
  String toString() => 'CategoryModel($id, $name, $type)';
}
