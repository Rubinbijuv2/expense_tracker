import 'package:expense_tracker/services/budget_alert_service.dart';
import 'package:expense_tracker/widgets/budget_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const limit = 500000; // ₹5,000

  group('BudgetAlertService.decide', () {
    BudgetAlert decide(int spent, {bool s80 = false, bool s100 = false}) =>
        BudgetAlertService.decide(spent, limit, s80, s100);

    test('below 80% → no alert', () {
      expect(decide(0), BudgetAlert.none);
      expect(decide(399999), BudgetAlert.none); // ₹3,999.99 = 79.99%
    });

    test('exactly 80% → 80% alert', () {
      expect(decide(400000), BudgetAlert.reached80);
    });

    test('between 80% and 100% → 80% alert only once', () {
      expect(decide(450000), BudgetAlert.reached80);
      expect(decide(450000, s80: true), BudgetAlert.none);
    });

    test('exactly 100% → 100% alert', () {
      expect(decide(500000), BudgetAlert.reached100);
      expect(decide(500000, s80: true), BudgetAlert.reached100);
    });

    test('jumping straight past 100% sends only the 100% alert', () {
      expect(decide(700000), BudgetAlert.reached100);
    });

    test('100% alert never repeats', () {
      expect(decide(700000, s80: true, s100: true), BudgetAlert.none);
      // Even if 80% was somehow not marked, nothing is sent once 100% was.
      expect(decide(700000, s100: true), BudgetAlert.none);
    });

    test('zero or negative limit → no alert', () {
      expect(BudgetAlertService.decide(100, 0, false, false), BudgetAlert.none);
    });
  });

  group('BudgetAlertService.alertText', () {
    test('80% text', () {
      final (title, body) = BudgetAlertService.alertText(
          BudgetAlert.reached80, 'Food budget', 400000, limit);
      expect(title, '80% of Food budget used');
      expect(body, '₹4,000 of ₹5,000 spent this month.');
    });

    test('100% text', () {
      final (title, body) = BudgetAlertService.alertText(
          BudgetAlert.reached100, 'monthly budget', 520050, limit);
      expect(title, 'Monthly budget exceeded');
      expect(body, 'You have spent ₹5,200.50 of your ₹5,000 monthly budget.');
    });
  });

  group('budgetLevel (bar colour)', () {
    test('green below 80%, amber from 80%, red from 100%', () {
      expect(budgetLevel(0, limit), BudgetLevel.ok);
      expect(budgetLevel(399999, limit), BudgetLevel.ok);
      expect(budgetLevel(400000, limit), BudgetLevel.warning);
      expect(budgetLevel(499999, limit), BudgetLevel.warning);
      expect(budgetLevel(500000, limit), BudgetLevel.over);
      expect(budgetLevel(900000, limit), BudgetLevel.over);
    });

    test('percent is a whole number and can pass 100', () {
      expect(budgetPercent(250000, limit), 50);
      expect(budgetPercent(399999, limit), 79);
      expect(budgetPercent(750000, limit), 150);
      expect(budgetPercent(100, 0), 0);
    });
  });
}
