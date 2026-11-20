import 'package:flutter/material.dart';

import 'utils/constants.dart';
import 'widgets/main_shell.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the phone's light/dark setting. A Settings option comes in step 10.
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}
