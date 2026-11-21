import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_lock_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/detected_sms_provider.dart';
import 'providers/history_provider.dart';
import 'providers/own_accounts_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/report_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/detected/detected_sms_screen.dart';
import 'screens/lock/lock_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
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

  // Read these before the first frame, so we know whether to show
  // onboarding or the lock screen without a flash of the Home screen.
  final settings = await SettingsProvider.load();
  final lock = await AppLockProvider.load();

  runApp(ExpenseTrackerApp(settings: settings, lock: lock));

  // App was closed and the user tapped "₹450 paid to Swiggy — tap to add".
  // (The lock screen still covers it until the PIN is entered.)
  if (openDetected && settings.onboardingDone) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDetectedScreen());
  }
}

void _openDetectedScreen() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute(builder: (_) => const DetectedSmsScreen()));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.settings,
    required this.lock,
  });

  final SettingsProvider settings;
  final AppLockProvider lock;

  @override
  Widget build(BuildContext context) {
    // MultiProvider puts several providers above every screen.
    // SettingsProvider / AppLockProvider: already loaded in main(), so they
    //   are passed in with `.value`.
    // TransactionProvider: `..load()` reads the database as soon as it is created.
    // DashboardProvider: gets the TransactionProvider so it can listen to it.
    // DetectedSmsProvider: `..start()` checks SMS permission and starts detection.
    // BudgetProvider: budgets of the month chosen on the Budgets screen.
    // HistoryProvider: search text, filters and matching rows for History.
    // ReportProvider: month, charts data and CSV/PDF export for Reports.
    // OwnAccountsProvider: Settings → My accounts (self-transfer detection).
    // RecurringProvider: repeat payments; `..load()` also creates any
    //   installments that became due since the app was last opened.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: lock),
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
        ChangeNotifierProvider(create: (_) => OwnAccountsProvider()..load()),
        ChangeNotifierProvider(
          create: (context) =>
              RecurringProvider(context.read<TransactionProvider>())..load(),
        ),
      ],
      // Consumer rebuilds only the MaterialApp when the theme setting changes.
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: s.themeMode,
          home: const AppGate(),
          // `builder` wraps every screen. The lock screen is drawn on top of
          // the Navigator, so whatever screen was open stays underneath.
          builder: (context, child) => _LockOverlay(child: child!),
        ),
      ),
    );
  }
}

/// First launch → onboarding. Afterwards → the main app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final done = context.select<SettingsProvider, bool>((s) => s.onboardingDone);
    return done ? const MainShell() : const OnboardingScreen();
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLockProvider, bool>((l) => l.isLocked);
    final onboardingDone =
        context.select<SettingsProvider, bool>((s) => s.onboardingDone);
    final showLock = locked && onboardingDone;
    return Stack(
      children: [
        // Offstage hides the app (it is not painted, so nothing shows through)
        // but keeps its state alive.
        Offstage(offstage: showLock, child: child),
        if (showLock) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
