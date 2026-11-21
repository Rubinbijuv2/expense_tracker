import '../data/budget_repo.dart';
import '../data/category_repo.dart';
import '../data/db_helper.dart';
import '../data/transaction_repo.dart';
import '../models/budget.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import 'demo_data_generator.dart';
import 'sms_service.dart';

/// "Load demo data" (Settings → tap Version 5 times): replaces all data with
/// the previous 2 full months + this month so far of realistic transactions,
/// budgets, and 2 pending detected SMS. For showing the app in the viva.
class DemoDataService {
  DemoDataService({DbHelper? helper}) : _helper = helper ?? DbHelper.instance;

  final DbHelper _helper;

  static const int overallBudgetPaise = 3200000; // ₹32,000
  static const Map<String, int> categoryBudgetsPaise = {
    'Food': 500000, // ₹5,000
    'Travel': 350000, // ₹3,500
  };

  /// Deletes everything, then inserts the demo data.
  /// Returns how many transactions were added.
  Future<int> replaceWithDemoData() async {
    await _helper.resetAllData();

    // Category name → id ("food" → 1). Defaults were just re-inserted.
    final cats = await CategoryRepo(_helper).getAll();
    final ids = {for (final c in cats) c.name.toLowerCase(): c.id!};
    final firstIncome = cats.firstWhere((c) => c.isIncome).id!;
    int idFor(DemoTxn d) =>
        ids[d.category.toLowerCase()] ??
        (d.type == 'income' ? firstIncome : ids['others']!);

    final now = DateTime.now();
    final demo = DemoDataGenerator.generate(now);
    await TransactionRepo(_helper).insertAll([
      for (final d in demo)
        TransactionModel(
          amountPaise: d.amountPaise,
          type: d.type,
          categoryId: idFor(d),
          paymentMode: d.mode,
          dateTime: d.dateTime,
          note: d.note,
          merchant: d.merchant,
          createdAt: d.dateTime,
        ),
    ]);

    await _addBudgets(demo, now, ids);
    await _addPendingSms(now);
    return demo.length;
  }

  /// Same budgets for each month. The 80%/100% "sent" flags match what was
  /// already spent, so the next real save gives a correct alert.
  Future<void> _addBudgets(
    List<DemoTxn> demo,
    DateTime now,
    Map<String, int> ids,
  ) async {
    final repo = BudgetRepo(_helper);
    for (final month in DemoDataGenerator.demoMonths(now)) {
      final inMonth = demo.where(
        (d) =>
            d.type == 'expense' &&
            d.dateTime.year == month.year &&
            d.dateTime.month == month.month,
      );
      Future<void> add(int? categoryId, int limit, int spent) => repo.insert(
        Budget(
          month: monthKey(month),
          categoryId: categoryId,
          limitPaise: limit,
          alert80Sent: spent * 100 >= limit * 80,
          alert100Sent: spent >= limit,
        ),
      );
      await add(
        null,
        overallBudgetPaise,
        inMonth.fold(0, (s, d) => s + d.amountPaise),
      );
      for (final e in categoryBudgetsPaise.entries) {
        final id = ids[e.key.toLowerCase()];
        if (id == null) continue;
        final spent = inMonth
            .where((d) => d.category == e.key)
            .fold(0, (s, d) => s + d.amountPaise);
        await add(id, e.value, spent);
      }
    }
  }

  /// Two bank SMS waiting on Home, sent through the real SMS pipeline
  /// (parser → category guess → pending). No notification is shown.
  Future<void> _addPendingSms(DateTime now) async {
    final service = SmsService();
    for (final (sender, body, at) in demoSms(now)) {
      await service.processMessage(sender, body, at);
    }
  }

  /// (sender, body, received at) of the demo SMS. Public for the unit test.
  static List<(String, String, DateTime)> demoSms(DateTime now) => [
    (
      'AX-HDFCBK',
      'Rs.386.00 debited from A/c XX1234 on ${_d(now)} to VPA '
          'zomato@hdfcbank (UPI Ref No 632412340001). Not you? Call 18002586161',
      now.subtract(const Duration(minutes: 40)),
    ),
    (
      'VM-SBIUPI',
      'Dear UPI user A/C X5678 debited by 214.0 on date ${_d(now)} trf to '
          'UBER INDIA Refno 432198760002. If not u? call 1800111109 -SBI',
      now.subtract(const Duration(hours: 3)),
    ),
  ];

  static String _d(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}-${t.month.toString().padLeft(2, '0')}-'
      '${(t.year % 100).toString().padLeft(2, '0')}';
}
