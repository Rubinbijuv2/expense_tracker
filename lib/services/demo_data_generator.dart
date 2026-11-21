import 'dart:math';

/// One generated demo transaction. The category is a name ('Food'), turned
/// into a real id when it is saved.
class DemoTxn {
  const DemoTxn(
    this.category,
    this.type,
    this.amountPaise,
    this.mode,
    this.dateTime,
    this.merchant, [
    this.note,
  ]);

  final String category;
  final String type; // 'expense' or 'income'
  final int amountPaise;
  final String mode;
  final DateTime dateTime;
  final String merchant;
  final String? note;
}

/// Builds realistic demo transactions. Pure Dart (no database), so it is
/// unit-tested. Saved to the database by DemoDataService.
class DemoDataGenerator {
  DemoDataGenerator._();

  /// First day of each demo month: 2 months ago, last month, this month.
  static List<DateTime> demoMonths(DateTime now) => [
    for (var i = 2; i >= 0; i--) DateTime(now.year, now.month - i),
  ];

  /// Pure (no database), so it is unit-tested. The same [now] and [seed]
  /// always give the same list. Nothing is later than [now]. Oldest first.
  static List<DemoTxn> generate(DateTime now, {int seed = 2026}) {
    final rnd = Random(seed);
    final out = <DemoTxn>[];
    int rupees(int min, int max) => (min + rnd.nextInt(max - min + 1)) * 100;
    T pick<T>(List<T> items) => items[rnd.nextInt(items.length)];

    final months = demoMonths(now);
    for (var m = 0; m < months.length; m++) {
      final month = months[m];
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      void add(
        int day,
        int hour,
        int minute,
        String cat,
        int paise,
        String mode,
        String merchant, [
        String? note,
        String type = 'expense',
      ]) {
        if (day > daysInMonth) return;
        final at = DateTime(month.year, month.month, day, hour, minute);
        if (at.isAfter(now)) return; // no future transactions
        out.add(DemoTxn(cat, type, paise, mode, at, merchant, note));
      }

      int day(int from, int to) => from + rnd.nextInt(to - from + 1);

      // ---- Every month -----------------------------------------------------
      add(
        1,
        10,
        5,
        'Salary',
        4500000,
        'Net banking',
        'ABC Technologies',
        'Monthly salary',
        'income',
      );
      add(3, 9, 30, 'Rent', 1200000, 'Net banking', 'Landlord', 'Flat rent');
      add(5, 19, 12, 'Bills', 29900, 'UPI', 'Jio', 'Mobile recharge');
      add(
        8,
        11,
        40,
        'Bills',
        rupees(950, 1450) + rnd.nextInt(100),
        'UPI',
        'Bescom',
        'Electricity bill',
      );
      add(10, 20, 3, 'Bills', 58900, 'UPI', 'Airtel', 'Broadband');
      add(12, 21, 30, 'Entertainment', 19900, 'Card', 'Netflix');
      add(
        day(13, 25),
        18,
        45,
        'Entertainment',
        rupees(380, 720),
        'UPI',
        'BookMyShow',
        'Movie tickets',
      );
      add(
        day(4, 26),
        17,
        20,
        'Health',
        rupees(180, 650),
        'UPI',
        'Apollo Pharmacy',
      );
      add(
        day(6, 24),
        8,
        15,
        'Travel',
        rupees(780, 1250),
        'UPI',
        'IRCTC',
        'Train ticket',
      );
      add(
        day(2, 12),
        18,
        50,
        'Shopping',
        rupees(1700, 2600),
        'Card',
        'DMart',
        'Monthly groceries',
      );
      add(
        day(16, 27),
        19,
        10,
        'Shopping',
        rupees(600, 1400),
        'Card',
        'DMart',
        'Groceries',
      );
      final online = [
        ('Amazon', 1299, 'Headphones'),
        ('Flipkart', 849, 'Phone cover'),
        ('Myntra', 1599, 'T-shirt'),
      ][m % 3];
      add(
        day(9, 27),
        22,
        5,
        'Shopping',
        online.$2 * 100,
        'UPI',
        online.$1,
        online.$3,
      );

      // ---- Some months only ---------------------------------------------
      if (m == 0) {
        add(14, 21, 0, 'Education', 49900, 'Card', 'Udemy', 'Flutter course');
      }
      if (m == 1) {
        add(
          15,
          16,
          25,
          'Salary',
          350000,
          'UPI',
          'Rahul Sharma',
          'Freelance website project',
          'income',
        );
        add(
          day(18, 26),
          12,
          0,
          'Education',
          32000,
          'Cash',
          'Sapna Book House',
          'Notebooks',
        );
      }

      // ---- Day-to-day spending ------------------------------------------
      for (var d = 1; d <= daysInMonth; d++) {
        if (rnd.nextDouble() < 0.30) {
          final lunch = rnd.nextBool();
          add(
            d,
            lunch ? 13 : 20,
            rnd.nextInt(60),
            'Food',
            rupees(150, 620),
            'UPI',
            pick(['Swiggy', 'Zomato', 'Swiggy', 'Dominos']),
            lunch ? 'Lunch' : 'Dinner',
          );
        }
        if (rnd.nextDouble() < 0.30) {
          add(
            d,
            16 + rnd.nextInt(2),
            rnd.nextInt(60),
            'Food',
            (3 + rnd.nextInt(10)) * 1000,
            'Cash',
            pick(['Chai Point', 'Local Tea Stall', 'Bakery']),
            'Snacks',
          );
        }
        if (rnd.nextDouble() < 0.35) {
          add(
            d,
            8 + rnd.nextInt(12),
            rnd.nextInt(60),
            'Travel',
            rupees(70, 320),
            'UPI',
            pick(['Uber', 'Ola', 'Rapido']),
          );
        }
      }
    }

    out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return out;
  }
}
