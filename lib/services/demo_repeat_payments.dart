import '../models/recurring_payment.dart';
import 'installment_schedule.dart';

/// One due date of a demo repeat payment.
class DemoInstallment {
  const DemoInstallment(this.dueDate, this.paidPaise);

  final DateTime dueDate;
  final int? paidPaise; // null = still pending

  bool get isPaid => paidPaise != null;
}

/// One demo repeat payment with its history. [payment] has categoryId 0;
/// DemoDataService puts in the real id of [categoryName] when it saves it.
class DemoRepeat {
  const DemoRepeat(
    this.payment,
    this.categoryName,
    this.merchant,
    this.installments,
  );

  final RecurringPayment payment;
  final String categoryName;
  final String merchant; // used on the expenses of paid months
  final List<DemoInstallment> installments; // oldest first
}

/// The demo repeat payments: one EMI, one chitti and one class fee
/// (PLAN.md 5.1). Pure Dart (no database), so it is unit-tested.
///
/// Due days are worked out from [now] so the demo always shows every state:
/// the chitti is 2 days overdue (red on Home, and a demo bank SMS matches
/// it), the fee is due in 3 days, and the EMI shows "10 of 24 paid".
class DemoRepeatPayments {
  DemoRepeatPayments._();

  static const int emiPaise = 320000; // ₹3,200
  static const int chittiPaise = 300000; // ₹3,000 (changes every month)
  static const int feePaise = 150000; // ₹1,500

  /// What was really paid for each chitti month (the dividend changes it).
  static const List<int> _chittiPaid = [
    272000,
    281000,
    288000,
    276000,
    290000,
    284000,
    295000,
  ];

  static List<DemoRepeat> build(DateTime now) {
    final today = InstallmentSchedule.dateOnly(now);
    final chittiDay = now.day >= 3 ? now.day - 2 : 1;
    final feeDay = now.day + 3 <= 28 ? now.day + 3 : 3;

    final emi = RecurringPayment(
      name: 'Bike EMI',
      type: 'emi',
      amountPaise: emiPaise,
      categoryId: 0,
      dueDay: 5,
      startDate: DateTime(now.year, now.month - 9, 1),
      totalInstallments: 24,
      paymentMode: 'Net banking',
      matchKeyword: 'BAJAJ FIN',
      notes: 'Bajaj Finance loan for the scooter',
      createdAt: DateTime(now.year, now.month - 9, 1),
    );
    final chitti = RecurringPayment(
      name: 'Sree Gokulam Chitti',
      type: 'chitti',
      amountPaise: chittiPaise,
      categoryId: 0,
      dueDay: chittiDay,
      startDate: DateTime(now.year, now.month - 6, 1),
      totalInstallments: 20,
      remindDaysBefore: 2,
      paymentMode: 'UPI',
      organiserName: 'Suresh Kumar',
      organiserPhone: '9847012345',
      notes: '₹60,000 chitti, 20 months',
      createdAt: DateTime(now.year, now.month - 6, 1),
    );
    final fee = RecurringPayment(
      name: 'Spoken English class',
      type: 'fee',
      amountPaise: feePaise,
      categoryId: 0,
      dueDay: feeDay,
      startDate: DateTime(now.year, now.month - 3, 1),
      endDate: DateTime(now.year, now.month + 4, 0), // end of month +3
      paymentMode: 'Cash',
      notes: 'Weekend batch, Sunrise Academy',
      createdAt: DateTime(now.year, now.month - 3, 1),
    );

    return [
      DemoRepeat(emi, 'Loan & EMI', 'Bajaj Finance', _history(emi, today)),
      DemoRepeat(
        chitti,
        'Chitti',
        'Sree Gokulam Chits',
        _history(
          chitti,
          today,
          lastLate: true,
          amount: (i) => _chittiPaid[i % _chittiPaid.length],
        ),
      ),
      DemoRepeat(
        fee,
        'Fees & Classes',
        'Sunrise Academy',
        _history(fee, today),
      ),
    ];
  }

  /// Every due date up to the next upcoming one (like RecurringProvider
  /// makes them). Dates before [today] are paid, except the last one when
  /// [lastLate] is true (it stays pending, so it shows as overdue).
  static List<DemoInstallment> _history(
    RecurringPayment p,
    DateTime today, {
    bool lastLate = false,
    int Function(int i)? amount,
  }) {
    final dates = InstallmentSchedule.datesThrough(p, today);
    final past = dates.where((d) => d.isBefore(today)).length;
    return [
      for (var i = 0; i < dates.length; i++)
        DemoInstallment(
          dates[i],
          i >= past || (lastLate && i == past - 1)
              ? null
              : (amount?.call(i) ?? p.amountPaise),
        ),
    ];
  }
}
