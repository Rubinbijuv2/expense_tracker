import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/transaction_provider.dart';
import 'utils/constants.dart';
import 'widgets/main_shell.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider makes one TransactionProvider available to every
    // screen below it. `..load()` reads the database as soon as it is created.
    return ChangeNotifierProvider(
      create: (_) => TransactionProvider()..load(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Follows the phone's light/dark setting. A Settings option comes in step 10.
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}
