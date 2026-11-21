import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/providers/app_lock_provider.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/screens/lock/lock_screen.dart';
import 'package:expense_tracker/screens/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('Bottom navigation shows 4 tabs and switches screens', (
    WidgetTester tester,
  ) async {
    // Onboarding finished and no PIN → straight to the main app.
    await tester.pumpWidget(
      ExpenseTrackerApp(
        settings: SettingsProvider(onboardingDone: true),
        lock: AppLockProvider(pinSet: false, fingerprintEnabled: false),
      ),
    );

    // All four tabs are in the navigation bar.
    final nav = find.byType(NavigationBar);
    for (final label in ['Home', 'History', 'Reports', 'Settings']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }

    // Home is selected first.
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 0);

    // Tapping Reports switches to the Reports screen.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 2);
    expect(find.byTooltip('Export CSV'), findsOneWidget);
    expect(find.byTooltip('Export PDF'), findsOneWidget);
  });

  testWidgets('First launch shows onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(
      ExpenseTrackerApp(
        settings: SettingsProvider(),
        lock: AppLockProvider(pinSet: false, fingerprintEnabled: false),
      ),
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Track every rupee'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('With a PIN, the app starts locked', (WidgetTester tester) async {
    await tester.pumpWidget(
      ExpenseTrackerApp(
        settings: SettingsProvider(onboardingDone: true, name: 'Asha'),
        lock: AppLockProvider(pinSet: true, fingerprintEnabled: false),
      ),
    );
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Welcome back, Asha'), findsOneWidget);
  });
}
