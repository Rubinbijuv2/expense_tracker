import '../data/budget_repo.dart';
import '../data/category_repo.dart';
import '../data/db_helper.dart';
import '../data/own_account_repo.dart';
import '../data/recurring_installment_repo.dart';
import '../data/recurring_payment_repo.dart';
import '../data/transaction_repo.dart';
import '../models/budget.dart';
import '../models/own_account.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import 'demo_data_generator.dart';
import 'demo_repeat_payments.dart';
import 'payment_notification_service.dart';
import 'sms_service.dart';

/// "Load demo data" (Settings → tap Version 5 times): replaces all data with
/// the previous 2 full months + this month so far of realistic transactions,
/// budgets, 3 repeat payments (EMI, chitti, fee), one own account, and
/// pending detected SMS + app notifications covering every card type.
/// For showing the app in the viva.
class DemoDataService {
  DemoDataService({DbHelper? helper}) : _helper = helper ?? DbHelper.instance;

  final DbHelper _helper;

  static const int overallBudgetPaise = 4000000; // ₹40,000
  static const Map<String, int> categoryBudgetsPaise = {
    'Food': 500000, // ₹5,000
    'Travel': 350000, // ₹3,500
  };

  /// Own account for the self-transfer demo SMS (Settings → My accounts).
  static const OwnAccount demoOwnAccount = OwnAccount(
    last4: '9012',
    label: 'SBI savings',
  );

  /// Deletes everything, then inserts the demo data.
  /// Returns how many transactions were added.
  Future<int> replaceWithDemoData() async {
    await _helper.resetAllData();

    // Category name → id ("food" → 1). Defaults were just re-inserted.
    final cats = await CategoryRepo(_helper).getAll();
    final ids = {for (final c in cats) c.name.toLowerCase(): c.id!};
    final firstIncome = cats.firstWhere((c) => c.isIncome).id!;
    int idFor(String category, String type) =>
        ids[category.toLowerCase()] ??
        (type == 'income' ? firstIncome : ids['others']!);

    final now = DateTime.now();
    final demo = DemoDataGenerator.generate(now);
    await TransactionRepo(_helper).insertAll([
      for (final d in demo)
        TransactionModel(
          amountPaise: d.amountPaise,
          type: d.type,
          categoryId: idFor(d.category, d.type),
          paymentMode: d.mode,
          dateTime: d.dateTime,
          note: d.note,
          merchant: d.merchant,
          createdAt: d.dateTime,
        ),
    ]);

    final repeatTxns = await _addRepeatPayments(now, idFor);
    await _addBudgets([...demo, ...repeatTxns], now, ids);
    await OwnAccountRepo(_helper).insert(demoOwnAccount);
    await _addDetected(now);
    return demo.length + repeatTxns.length;
  }

  /// Saves the EMI, chitti and fee with their installments. Paid months
  /// inside the demo months get a linked expense (like "Mark as paid");
  /// older paid months have none (like "Mark earlier ones as paid").
  /// Returns the added expenses, so the budgets count them too.
  Future<List<DemoTxn>> _addRepeatPayments(
    DateTime now,
    int Function(String category, String type) idFor,
  ) async {
    final payRepo = RecurringPaymentRepo(_helper);
    final instRepo = RecurringInstallmentRepo(_helper);
    final txnRepo = TransactionRepo(_helper);
    final firstDemoDay = DemoDataGenerator.demoMonths(now).first;
    final added = <DemoTxn>[];

    for (final r in DemoRepeatPayments.build(now)) {
      final categoryId = idFor(r.categoryName, 'expense');
      final p = RecurringPayment.fromMap({
        ...r.payment.toMap(),
        'category_id': categoryId,
      });
      final id = await payRepo.insert(p);
      await instRepo.insertPending(id, [
        for (final i in r.installments) i.dueDate,
      ]);
      // Same order as r.installments (both oldest first).
      final saved = await instRepo.getFor(id);
      for (var k = 0; k < saved.length; k++) {
        final demoInst = r.installments[k];
        if (!demoInst.isPaid) continue;
        final at = demoInst.dueDate.add(const Duration(hours: 10));
        int? txnId;
        if (!at.isBefore(firstDemoDay)) {
          txnId = await txnRepo.insert(
            TransactionModel(
              amountPaise: demoInst.paidPaise!,
              type: 'expense',
              categoryId: categoryId,
              paymentMode: p.paymentMode,
              dateTime: at,
              note: p.name,
              merchant: r.merchant,
              createdAt: at,
              recurringId: id,
            ),
          );
          added.add(
            DemoTxn(
              r.categoryName,
              'expense',
              demoInst.paidPaise!,
              p.paymentMode,
              at,
              r.merchant,
              p.name,
            ),
          );
        }
        await instRepo.update(saved[k].paid(demoInst.paidPaise!, txnId, at));
      }
    }
    return added;
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

  /// Pending cards on Home and the Detected SMS screen, sent through the
  /// real SMS and notification pipelines (parser → category guess → self
  /// transfer → Bank + Receipt pairing → pending). No notification is shown.
  Future<void> _addDetected(DateTime now) async {
    final sms = SmsService();
    for (final (sender, body, at) in demoSms(now)) {
      await sms.processMessage(sender, body, at);
    }
    final apps = PaymentNotificationService(smsService: sms);
    for (final n in demoNotifications(now)) {
      await apps.process(n);
    }
  }

  /// (sender, body, received at) of the demo SMS. Public for the unit test.
  static List<(String, String, DateTime)> demoSms(DateTime now) => [
    // Bank cards.
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
    // Matches the overdue chitti: "Mark Sree Gokulam Chitti as paid?"
    (
      'AX-HDFCBK',
      'Rs.2,950.00 debited from A/c XX1234 on ${_d(now)} to VPA '
          'sreegokulam@sbi (UPI Ref No 632412340003). Not you? Call 18002586161',
      now.subtract(const Duration(minutes: 90)),
    ),
    // Bank half of the "Found in Google Pay and bank SMS" card.
    (
      'AX-HDFCBK',
      'Rs.640.00 debited from A/c XX1234 on ${_d(now)} to VPA '
          'dmart@icici (UPI Ref No 632412340004). Not you? Call 18002586161',
      now.subtract(const Duration(hours: 2)),
    ),
    // Receipt card.
    (
      'AD-VAAHAN-S',
      'Payment received for Vehicle KL07AB1234 PUC fee Rs 120.00. '
          'Transaction ID VH998877. Thank you, Team Vaahan',
      now.subtract(const Duration(hours: 5)),
    ),
    // Self transfer to the demo own account (shown greyed).
    (
      'AX-HDFCBK-S',
      'Rs.5,000.00 sent from A/c XX1234 to A/c XX9012 via IMPS on ${_d(now)}. '
          'Ref No 445577',
      now.subtract(const Duration(days: 1)),
    ),
  ];

  /// Demo payment app notifications. Public for the unit test.
  static List<AppNotification> demoNotifications(DateTime now) => [
    // Same payment as the DMart bank SMS, 1 minute later → merged card.
    AppNotification(
      packageName: 'com.google.android.apps.nbu.paisa.user',
      title: 'Payment successful',
      text: '₹640 paid to DMart',
      postedAt: now.subtract(const Duration(minutes: 119)),
    ),
    // Money received (App card, income).
    AppNotification(
      packageName: 'com.phonepe.app',
      title: 'Received ₹1,000 from Anu Joseph',
      text: 'Money credited to your bank account',
      postedAt: now.subtract(const Duration(hours: 6)),
    ),
  ];

  static String _d(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}-${t.month.toString().padLeft(2, '0')}-'
      '${(t.year % 100).toString().padLeft(2, '0')}';
}
