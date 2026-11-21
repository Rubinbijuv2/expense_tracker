import 'package:flutter/foundation.dart';

import '../models/report_summary.dart';
import '../services/export_service.dart';
import 'transaction_provider.dart';

/// Data for the Reports screen: the chosen month, its report, and exports.
///
/// Like DashboardProvider it listens to [TransactionProvider], so the charts
/// update as soon as a transaction is added, edited or deleted.
class ReportProvider extends ChangeNotifier {
  ReportProvider(this._txns, {ExportService? exportService})
      : _export = exportService ?? ExportService() {
    _txns.addListener(_recompute);
    _recompute();
  }

  final TransactionProvider _txns;
  final ExportService _export;

  DateTime _month = _monthOf(DateTime.now());
  late ReportSummary _summary;
  bool _exporting = false;

  DateTime get month => _month;
  ReportSummary get summary => _summary;
  bool get isLoading => _txns.isLoading;

  /// True while a CSV/PDF is being built (the export buttons are disabled).
  bool get isExporting => _exporting;

  /// Nothing to export in an empty month.
  bool get canExport => !_exporting && _summary.transactions.isNotEmpty;

  bool get canGoNext => _month.isBefore(_monthOf(DateTime.now()));

  void previousMonth() => _setMonth(DateTime(_month.year, _month.month - 1));

  void nextMonth() {
    if (canGoNext) _setMonth(DateTime(_month.year, _month.month + 1));
  }

  void _setMonth(DateTime m) {
    _month = m;
    _recompute();
  }

  void _recompute() {
    _summary = ReportSummary.compute(_txns.transactions, _month);
    notifyListeners();
  }

  String _categoryName(int id) => _txns.categoryById(id)?.name ?? 'Unknown';

  /// Saves and shares the month as CSV. Returns an error message, or null if OK.
  Future<String?> exportCsv() =>
      _run(() => _export.exportCsv(_summary, _categoryName));

  /// Saves and shares the month as PDF. Returns an error message, or null if OK.
  Future<String?> exportPdf() =>
      _run(() => _export.exportPdf(_summary, _categoryName));

  Future<String?> _run(Future<Object?> Function() job) async {
    if (_exporting) return null;
    _exporting = true;
    notifyListeners();
    try {
      await job();
      return null;
    } catch (e) {
      debugPrint('Export failed: $e');
      return 'Export failed: $e';
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  @override
  void dispose() {
    _txns.removeListener(_recompute);
    super.dispose();
  }
}
