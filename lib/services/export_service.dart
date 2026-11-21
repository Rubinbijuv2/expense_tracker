import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/report_summary.dart';
import '../utils/formatters.dart';

/// Turns a category id into its name (TransactionProvider gives this).
typedef CategoryNamer = String Function(int categoryId);

/// Builds CSV and PDF files for one month, saves them in the app's
/// documents folder and opens the Android share sheet.
class ExportService {
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _monthTitle = DateFormat('MMMM yyyy');

  static const List<String> csvHeader = [
    'Date', 'Type', 'Category', 'Amount (INR)', 'Payment mode', //
    'Merchant', 'Note', 'Source',
  ];

  /// "expenses_2026-11" (the extension is added by the caller).
  static String fileBaseName(DateTime month) => 'expenses_${monthKey(month)}';

  /// 123450 → "1234.50". A plain number so spreadsheets can add it up.
  static String plainRupees(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  /// Header + one row per transaction (newest first). Pure, so it is unit-tested.
  static List<List<String>> csvRows(
    ReportSummary r,
    CategoryNamer categoryName,
  ) {
    return [
      csvHeader,
      for (final t in r.transactions)
        [
          _dateFmt.format(t.dateTime),
          t.isExpense ? 'Expense' : 'Income',
          categoryName(t.categoryId),
          plainRupees(t.amountPaise),
          t.paymentMode,
          t.merchant ?? '',
          t.note ?? '',
          t.source,
        ],
    ];
  }

  /// The CSV text. `addBom` lets Excel read it as UTF-8 (₹, Hindi names).
  static String buildCsv(ReportSummary r, CategoryNamer categoryName) =>
      Csv(addBom: true).encode(csvRows(r, categoryName));

  /// The PDF's built-in font has no ₹ glyph, so the PDF uses "Rs." instead.
  static String pdfMoney(int paise) =>
      formatPaise(paise).replaceFirst('₹', 'Rs. ');

  /// The built-in PDF font only knows Latin letters; anything else becomes '?'
  /// instead of an empty box.
  static String pdfSafe(String s) =>
      s.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), '?');

  /// A one-or-more page A4 PDF: title, totals, then a table of transactions.
  static Future<Uint8List> buildPdf(
    ReportSummary r,
    CategoryNamer categoryName,
  ) async {
    final doc = pw.Document(title: 'Expense Report ${monthKey(r.month)}');
    final title = 'Expense Report - ${_monthTitle.format(r.month)}';

    // MultiPage flows a long table onto as many pages as it needs.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          _pdfTotals(r),
          pw.SizedBox(height: 20),
          pw.Text(
            'Transactions (${r.transactions.length})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (r.transactions.isEmpty)
            pw.Text('No transactions this month.')
          else
            _pdfTable(r, categoryName),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _pdfTotals(ReportSummary r) {
    pw.Widget cell(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(right: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    return pw.Row(
      children: [
        cell('Spent', pdfMoney(r.spentPaise)),
        cell('Income', pdfMoney(r.incomePaise)),
        cell('Balance', pdfMoney(r.balancePaise)),
        cell('Average / day', pdfMoney(r.averagePerDayPaise)),
      ],
    );
  }

  static pw.Widget _pdfTable(ReportSummary r, CategoryNamer categoryName) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Type',
        'Category',
        'Merchant / Note',
        'Mode',
        'Amount',
      ],
      data: [
        for (final t in r.transactions)
          [
            _dateFmt.format(t.dateTime),
            t.isExpense ? 'Expense' : 'Income',
            pdfSafe(categoryName(t.categoryId)),
            pdfSafe(
              t.merchant?.isNotEmpty == true ? t.merchant! : (t.note ?? ''),
            ),
            t.paymentMode,
            pdfMoney(t.amountPaise),
          ],
      ],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {5: pw.Alignment.centerRight},
      headerAlignments: {5: pw.Alignment.centerRight},
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FixedColumnWidth(48),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FlexColumnWidth(),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(75),
      },
    );
  }

  /// Saves [bytes] as [fileName] in the app's private documents folder
  /// and returns the file.
  Future<File> _save(String fileName, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _share(File file, String mimeType, DateTime month) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: 'Expense report ${_monthTitle.format(month)}',
      ),
    );
  }

  /// Builds the CSV, saves it and opens the share sheet. Returns the saved file.
  Future<File> exportCsv(ReportSummary r, CategoryNamer categoryName) async {
    // Written as UTF-8 bytes so the "\r\n" line endings stay exactly as built.
    final bytes = utf8.encode(buildCsv(r, categoryName));
    final file = await _save('${fileBaseName(r.month)}.csv', bytes);
    await _share(file, 'text/csv', r.month);
    return file;
  }

  /// Builds the PDF, saves it and opens the share sheet. Returns the saved file.
  Future<File> exportPdf(ReportSummary r, CategoryNamer categoryName) async {
    final bytes = await buildPdf(r, categoryName);
    final file = await _save('${fileBaseName(r.month)}.pdf', bytes);
    await _share(file, 'application/pdf', r.month);
    return file;
  }
}
