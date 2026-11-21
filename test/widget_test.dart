import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('Bottom navigation shows 4 tabs and switches screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());

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
}
