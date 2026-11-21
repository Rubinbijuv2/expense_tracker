import 'package:expense_tracker/models/report_summary.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/export_service.dart';
import 'package:expense_tracker/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _txn(int id, int paise, String type, DateTime when,
        {String? merchant, String? note, int cat = 1}) =>
    TransactionModel(
      id: id,
      amountPaise: paise,
      type: type,
      categoryId: cat,
      paymentMode: 'UPI',
      dateTime: when,
      merchant: merchant,
      note: note,
    );

/// Newest first, like TransactionProvider.
List<TransactionModel> _sorted(List<TransactionModel> t) =>
    t..sort((a, b) => b.dateTime.compareTo(a.dateTime));

String _cat(int id) => id == 1 ? 'Food' : 'Salary';

void main() {
  final nov = DateTime(2026, 11);
  final today = DateTime(2026, 11, 21, 15);

  test('empty month gives zeros and the right number of days', () {
    final r = ReportSummary.compute([], nov, today: today);
    expect(r.spentPaise, 0);
    expect(r.incomePaise, 0);
    expect(r.averagePerDayPaise, 0);
    expect(r.dailySpentPaise.length, 30); // November
    expect(r.lastSixMonths.length, 6);
    expect(r.topMerchants, isEmpty);
    expect(r.transactions, isEmpty);
  });

  test('last 6 months cross the year and only count expenses', () {
    final txns = _sorted([
      _txn(1, 10000, 'expense', DateTime(2026, 11, 3)),
      _txn(2, 20000, 'expense', DateTime(2026, 8, 31, 23, 59)),
      _txn(3, 99900, 'income', DateTime(2026, 8, 1)),
      _txn(4, 5000, 'expense', DateTime(2026, 1, 15)),
      _txn(5, 7000, 'expense', DateTime(2025, 12, 31)), // 7th month back: excluded
    ]);
    final r = ReportSummary.compute(txns, DateTime(2026, 2), today: today);
    expect(r.lastSixMonths.map((m) => m.month).toList(), [
      DateTime(2025, 9),
      DateTime(2025, 10),
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
    expect(r.lastSixMonths.map((m) => m.spentPaise).toList(),
        [0, 0, 0, 7000, 5000, 0]);

    final r2 = ReportSummary.compute(txns, nov, today: today);
    expect(r2.lastSixMonths.map((m) => m.spentPaise).toList(),
        [0, 0, 20000, 0, 0, 10000]); // Jun..Nov
  });

  test('daily totals and month boundaries', () {
    final txns = _sorted([
      _txn(1, 10000, 'expense', DateTime(2026, 11, 1, 0, 0)),
      _txn(2, 2550, 'expense', DateTime(2026, 11, 1, 18)),
      _txn(3, 40000, 'expense', DateTime(2026, 11, 30, 23, 59)),
      _txn(4, 50000, 'income', DateTime(2026, 11, 5)),
      _txn(5, 1, 'expense', DateTime(2026, 12, 1)), // next month
      _txn(6, 1, 'expense', DateTime(2026, 10, 31, 23, 59)), // last month
    ]);
    final r = ReportSummary.compute(txns, nov, today: DateTime(2026, 12, 5));
    expect(r.dailySpentPaise[0], 12550);
    expect(r.dailySpentPaise[29], 40000);
    expect(r.dailySpentPaise.reduce((a, b) => a + b), 52550);
    expect(r.spentPaise, 52550);
    expect(r.incomePaise, 50000);
    expect(r.balancePaise, -2550);
    expect(r.transactions.length, 4); // includes income
  });

  test('average per day: days so far for this month, all days for past months', () {
    final txns = [_txn(1, 21000, 'expense', DateTime(2026, 11, 2))];
    final current = ReportSummary.compute(txns, nov, today: today);
    expect(current.daysCounted, 21);
    expect(current.averagePerDayPaise, 1000);

    final past = ReportSummary.compute(txns, nov, today: DateTime(2027, 1, 1));
    expect(past.daysCounted, 30);
    expect(past.averagePerDayPaise, 700);

    final feb = ReportSummary.compute([], DateTime(2028, 2), today: today);
    expect(feb.daysInMonth, 29); // leap year
  });

  test('top merchants: grouped ignoring case, biggest first, max 5', () {
    final d = DateTime(2026, 11, 10);
    final txns = _sorted([
      _txn(1, 30000, 'expense', d.add(const Duration(hours: 1)), merchant: 'Swiggy'),
      _txn(2, 20000, 'expense', d, merchant: 'swiggy '),
      _txn(3, 45000, 'expense', d, merchant: 'Amazon'),
      _txn(4, 100, 'expense', d, merchant: 'A'),
      _txn(5, 200, 'expense', d, merchant: 'B'),
      _txn(6, 300, 'expense', d, merchant: 'C'),
      _txn(7, 900, 'expense', d), // no merchant
      _txn(8, 999999, 'income', d, merchant: 'Employer'), // income ignored
    ]);
    final r = ReportSummary.compute(txns, nov, today: today);
    expect(r.topMerchants.length, 5);
    expect(r.topMerchants.first.name, 'Swiggy'); // newest spelling kept
    expect(r.topMerchants.first.totalPaise, 50000);
    expect(r.topMerchants.first.count, 2);
    expect(r.topMerchants[1].name, 'Amazon');
    expect(r.topMerchants[2].name, ReportSummary.unknownMerchant);
    expect(r.topMerchants.map((m) => m.name), isNot(contains('Employer')));
    expect(r.topMerchants.map((m) => m.name), isNot(contains('A')));
  });

  group('export', () {
    test('CSV rows have a header and one row per transaction', () {
      final txns = _sorted([
        _txn(1, 45050, 'expense', DateTime(2026, 11, 3, 9, 5),
            merchant: 'Swiggy', note: 'Lunch, with "team"'),
        _txn(2, 5000000, 'income', DateTime(2026, 11, 1), cat: 9),
      ]);
      final r = ReportSummary.compute(txns, nov, today: today);
      final rows = ExportService.csvRows(r, _cat);
      expect(rows.first, ExportService.csvHeader);
      expect(rows.length, 3);
      expect(rows[1], [
        '2026-11-03 09:05', 'Expense', 'Food', '450.50', 'UPI', //
        'Swiggy', 'Lunch, with "team"', 'manual',
      ]);
      expect(rows[2][1], 'Income');
      expect(rows[2][2], 'Salary');
      expect(rows[2][3], '50000.00');

      // Commas and quotes in a note are escaped properly in the CSV text.
      final text = ExportService.buildCsv(r, _cat);
      expect(text, contains('"Lunch, with ""team"""'));
    });

    test('helpers', () {
      expect(ExportService.plainRupees(5), '0.05');
      expect(ExportService.plainRupees(123450), '1234.50');
      expect(ExportService.pdfMoney(123450), 'Rs. 1,234.50');
      expect(ExportService.pdfMoney(-50000), '-Rs. 500.00');
      expect(ExportService.pdfSafe('Café ☕ दुकान'), 'Café ? ?????');
      expect(ExportService.fileBaseName(nov), 'expenses_2026-11');
    });

    test('PDF builds and starts with the PDF signature', () async {
      final txns = [
        for (var i = 0; i < 80; i++) // enough rows for more than one page
          _txn(i, 1000 + i, 'expense', DateTime(2026, 11, 1 + i % 20),
              merchant: 'Shop $i'),
      ];
      final r = ReportSummary.compute(_sorted(txns), nov, today: today);
      final bytes = await ExportService.buildPdf(r, _cat);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  test('compact chart labels', () {
    expect(formatPaiseCompact(0), '₹0');
    expect(formatPaiseCompact(120000), '₹1.2K');
    expect(formatPaiseCompact(25000000), '₹2.5L');
  });
}
