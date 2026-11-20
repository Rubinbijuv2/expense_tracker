import '../models/category_model.dart';

/// The 10 categories inserted the first time the database is created.
/// `icon` is a key from `utils/category_icons.dart`; `color` is an ARGB int.
const List<CategoryModel> defaultCategories = [
  CategoryModel(name: 'Food', icon: 'restaurant', color: 0xFFEF6C00, type: 'expense', isDefault: true),
  CategoryModel(name: 'Travel', icon: 'directions_car', color: 0xFF1E88E5, type: 'expense', isDefault: true),
  CategoryModel(name: 'Shopping', icon: 'shopping_bag', color: 0xFFD81B60, type: 'expense', isDefault: true),
  CategoryModel(name: 'Bills', icon: 'receipt_long', color: 0xFF6D4C41, type: 'expense', isDefault: true),
  CategoryModel(name: 'Rent', icon: 'home', color: 0xFF5E35B1, type: 'expense', isDefault: true),
  CategoryModel(name: 'Health', icon: 'local_hospital', color: 0xFFE53935, type: 'expense', isDefault: true),
  CategoryModel(name: 'Education', icon: 'school', color: 0xFF00897B, type: 'expense', isDefault: true),
  CategoryModel(name: 'Entertainment', icon: 'movie', color: 0xFF8E24AA, type: 'expense', isDefault: true),
  CategoryModel(name: 'Salary', icon: 'account_balance_wallet', color: 0xFF43A047, type: 'income', isDefault: true),
  CategoryModel(name: 'Others', icon: 'category', color: 0xFF757575, type: 'expense', isDefault: true),
];
