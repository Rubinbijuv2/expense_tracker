import '../models/category_model.dart';

/// Default categories (PLAN.md section 4, rule 11).
/// `icon` is a key from `utils/category_icons.dart`; `color` is an ARGB int.
///
/// The first 10 are the version 1 list, in the same order, so a new install
/// and an upgraded phone give them the same ids. The version 2 additions come
/// after them; the migration inserts only the ones that are missing.
const List<CategoryModel> defaultCategories = [
  // ---- Version 1 ----
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
  // ---- Version 2 ----
  CategoryModel(name: 'Tax & Govt', icon: 'account_balance', color: 0xFF455A64, type: 'expense', isDefault: true),
  CategoryModel(name: 'Vehicle', icon: 'two_wheeler', color: 0xFF3949AB, type: 'expense', isDefault: true),
  CategoryModel(name: 'Loan & EMI', icon: 'credit_score', color: 0xFFC62828, type: 'expense', isDefault: true),
  CategoryModel(name: 'Chitti', icon: 'groups', color: 0xFF00838F, type: 'expense', isDefault: true),
  CategoryModel(name: 'Fees & Classes', icon: 'menu_book', color: 0xFF6A1B9A, type: 'expense', isDefault: true),
  CategoryModel(name: 'Money received', icon: 'payments', color: 0xFF2E7D32, type: 'income', isDefault: true),
  CategoryModel(name: 'Refund', icon: 'currency_exchange', color: 0xFF00897B, type: 'income', isDefault: true),
  CategoryModel(name: 'Cashback', icon: 'redeem', color: 0xFFF9A825, type: 'income', isDefault: true),
  CategoryModel(name: 'Chitti received', icon: 'volunteer_activism', color: 0xFF00695C, type: 'income', isDefault: true),
  CategoryModel(name: 'Others (income)', icon: 'more_horiz', color: 0xFF616161, type: 'income', isDefault: true),
];
