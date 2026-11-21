import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/budget_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/detected_sms_provider.dart';
import 'providers/history_provider.dart';
import 'providers/report_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/detected/detected_sms_screen.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'widgets/main_shell.dart';

/// Lets code outside the widget tree (a tapped notification) open a screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Needed before using plugins (notifications) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  var openDetected = false;
  try {
    await NotificationService.instance.init(onTap: _openDetectedScreen);
    openDetected = await NotificationService.instance.launchedFromNotification();
  } catch (e) {
    debugPrint('Notifications not available: $e');
  }

  runApp(const ExpenseTrackerApp());

  // App was closed and the user tapped "₹450 paid to Swiggy — tap to add".
  if (openDetected) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDetectedScreen());
  }
}

void _openDetectedScreen() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(builder: (_) => const DetectedSmsScreen()));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider puts several providers above every screen.
    // TransactionProvider: `..load()` reads the database as soon as it is created.
    // DashboardProvider: gets the TransactionProvider so it can listen to it.
    // DetectedSmsProvider: `..start()` checks SMS permission and starts detection.
    // BudgetProvider: budgets of the month chosen on the Budgets screen.
    // HistoryProvider: search text, filters and matching rows for History.
    // ReportProvider: month, charts data and CSV/PDF export for Reports.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()..load()),
        ChangeNotifierProvider(
          create: (context) =>
              DashboardProvider(context.read<TransactionProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              DetectedSmsProvider(context.read<TransactionProvider>())..start(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              BudgetProvider(context.read<TransactionProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              HistoryProvider(context.read<TransactionProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ReportProvider(context.read<TransactionProvider>()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
