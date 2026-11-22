import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'providers/app_lock_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/detected_sms_provider.dart';
import 'providers/history_provider.dart';
import 'providers/own_accounts_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/repeat_suggestion_provider.dart';
import 'providers/report_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/add_edit/add_edit_screen.dart';
import 'screens/detected/detected_sms_screen.dart';
import 'screens/lock/lock_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/recurring/reminder_actions.dart';
import 'services/backup_service.dart';
import 'services/cash_reminder_service.dart';
import 'services/notification_service.dart';
import 'services/payment_notification_service.dart';
import 'services/reminder_planner.dart';
import 'utils/constants.dart';
import 'widgets/main_shell.dart';

/// Lets code outside the widget tree (a tapped notification) open a screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Needed before using plugins (notifications) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  NotificationResponse? launchTap;
  try {
    await NotificationService.instance.init(onResponse: _onNotificationTap);
    launchTap = await NotificationService.instance.launchResponse();
  } catch (e) {
    debugPrint('Notifications not available: $e');
  }

  // Read these before the first frame, so we know whether to show
  // onboarding or the lock screen without a flash of the Home screen.
  final settings = await SettingsProvider.load();
  final lock = await AppLockProvider.load();

  runApp(ExpenseTrackerApp(settings: settings, lock: lock));

  // Daily "Spent any cash today?" reminder: scheduled again on every start,
  // so a changed time zone or a cleared alarm is fixed. Not awaited, so it
  // never slows down opening the app.
  settings.applyCashReminder();

  // Remove backup copies a previous share left in the cache (they hold
  // all data). Not awaited either; it never throws.
  BackupService.clearOldBackups();

  // App was closed and the user tapped one of our notifications
  // ("₹450 paid to Swiggy — tap to add", a repeat-payment reminder or the
  // daily cash reminder).
  // (The lock screen still covers it until the PIN is entered.)
  if (launchTap != null && settings.onboardingDone) {
    final tap = launchTap;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onNotificationTap(tap),
    );
  }
}

/// Started by the Kotlin PaymentNotificationListener (in a hidden Flutter
/// engine) when a payment app notification arrives while the app is closed.
/// `@pragma('vm:entry-point')` keeps it in release builds, because no Dart
/// code calls it. It must be in main.dart, where Kotlin looks for it.
@pragma('vm:entry-point')
Future<void> paymentNotificationMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PaymentNotificationService.runInBackground();
}

/// A notification, or one of its buttons that opens the app, was tapped.
void _onNotificationTap(NotificationResponse r) {
  if (r.payload == CashReminderService.payload) {
    final nav = navigatorKey.currentState;
    nav?.push(
      MaterialPageRoute(
        builder: (_) => const AddEditScreen(initialPaymentMode: 'Cash'),
      ),
    );
    return;
  }
  final reminder = ReminderPayload.parse(r.payload);
  if (reminder != null) {
    final context = navigatorKey.currentContext;
    if (context != null) handleReminderResponse(context, r.actionId, reminder);
    return;
  }
  // Detected SMS: only the notification itself (Save / Ignore run in the
  // background without opening the app).
  if (r.actionId == null) _openDetectedScreen();
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
    // RecurringProvider: repeat payments; `..ensureLoaded()` also creates
    //   any installments that became due since the app was last opened and
    //   schedules the reminders. `lazy: false` creates it at start-up
    //   (providers are normally created only when a screen first reads them).
    // RepeatSuggestionProvider: "Make it a repeat payment?" cards on Home.
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
          lazy: false,
          create: (context) =>
              RecurringProvider(context.read<TransactionProvider>())
                ..ensureLoaded(),
        ),
        ChangeNotifierProvider(
          create: (context) => RepeatSuggestionProvider(
            context.read<TransactionProvider>(),
            context.read<RecurringProvider>(),
          ),
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
    final done = context.select<SettingsProvider, bool>(
      (s) => s.onboardingDone,
    );
    return done ? const MainShell() : const OnboardingScreen();
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLockProvider, bool>((l) => l.isLocked);
    final onboardingDone = context.select<SettingsProvider, bool>(
      (s) => s.onboardingDone,
    );
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
