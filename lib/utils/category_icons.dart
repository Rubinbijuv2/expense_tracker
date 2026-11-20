import 'package:flutter/material.dart';

/// Icons a category can use, stored in the database by name.
///
/// We store the name (e.g. 'restaurant') instead of the icon's number because
/// release builds only keep icons written directly in code; this map keeps them.
const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'home': Icons.home,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'movie': Icons.movie,
  'account_balance_wallet': Icons.account_balance_wallet,
  'category': Icons.category,
  // Extra choices for custom categories.
  'local_cafe': Icons.local_cafe,
  'local_grocery_store': Icons.local_grocery_store,
  'fastfood': Icons.fastfood,
  'flight': Icons.flight,
  'train': Icons.train,
  'local_gas_station': Icons.local_gas_station,
  'phone_android': Icons.phone_android,
  'wifi': Icons.wifi,
  'bolt': Icons.bolt,
  'fitness_center': Icons.fitness_center,
  'pets': Icons.pets,
  'child_care': Icons.child_care,
  'card_giftcard': Icons.card_giftcard,
  'savings': Icons.savings,
  'work': Icons.work,
  'sports_esports': Icons.sports_esports,
  'checkroom': Icons.checkroom,
  'build': Icons.build,
};

/// Returns the icon for [name], or a generic icon if the name is unknown.
IconData iconFor(String name) => categoryIcons[name] ?? Icons.category;
