import 'package:flutter/material.dart';

/// App-wide constants (name, colours, themes).
class AppConstants {
  AppConstants._(); // Not meant to be instantiated.

  static const String appName = 'Expense Tracker';

  /// Seed colour: Material 3 generates the whole colour palette from this.
  static const Color seedColor = Colors.teal;

  /// Payment modes shown as chips on the Add/Edit screen.
  static const List<String> paymentModes = ['Cash', 'UPI', 'Card', 'Net banking'];
  static const String defaultPaymentMode = 'UPI';
}

/// Light and dark Material 3 themes built from the same teal seed colour.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
