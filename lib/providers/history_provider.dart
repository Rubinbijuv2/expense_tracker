import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/transaction_repo.dart';
import '../models/category_model.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import 'transaction_provider.dart';

/// Search text, filters and the matching transactions for the History screen.
///
/// The filtering happens in SQL (see [TransactionFilter.toWhere]). It listens
/// to [TransactionProvider], so the list re-queries after every add, edit,
/// delete or undo.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._txns, {TransactionRepo? repo})
    : _repo = repo ?? TransactionRepo() {
    _txns.addListener(_onTransactionsChanged);
    _refresh();
  }

  final TransactionProvider _txns;
  final TransactionRepo _repo;

  TransactionFilter _filter = const TransactionFilter();
  List<TransactionModel> _results = [];
  int _spentPaise = 0;
  int _incomePaise = 0;
  bool _loading = true;
  String? _error;

  // Each query gets a number; an answer from an older query is thrown away.
  int _requestNo = 0;

  // A Timer runs code once after a delay. Used to wait until the user stops
  // typing (300 ms) before searching, instead of querying on every key press.
  Timer? _debounce;

  TransactionFilter get filter => _filter;
  List<TransactionModel> get results => List.unmodifiable(_results);
  int get spentPaise => _spentPaise;
  int get incomePaise => _incomePaise;
  bool get isLoading => _loading;
  String? get error => _error;

  /// True when the database has no transactions at all (not just no matches).
  bool get hasNoTransactions => !_txns.isLoading && _txns.transactions.isEmpty;

  List<DayGroup> get groupedByDay => TransactionProvider.groupByDay(_results);

  CategoryModel? categoryById(int id) => _txns.categoryById(id);

  /// Categories for the filter sheet: those of [type], or all when null.
  List<CategoryModel> categoriesFor(String? type) => type == null
      ? [..._txns.categoriesFor('expense'), ..._txns.categoriesFor('income')]
      : _txns.categoriesFor(type);

  /// Called on every key press in the search bar.
  void setQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (text == _filter.query) return;
      _filter = _filter.copyWith(query: text);
      _refresh();
    });
  }

  /// Replaces the filters (from the sheet or a removed chip).
  /// The search text in [_filter] is kept.
  void applyFilter(TransactionFilter f) {
    _filter = f.copyWith(query: _filter.query);
    _refresh();
  }

  void clearFilters() => applyFilter(_filter.clearFilters());

  /// Removes the search text and every filter at once (no typing delay).
  void clearAll() {
    _debounce?.cancel();
    _filter = const TransactionFilter();
    _refresh();
  }

  void _onTransactionsChanged() {
    // A swiped row is removed from TransactionProvider at once, but the DB
    // delete finishes a moment later. Drop missing rows right away so the
    // swiped row never re-appears, then query again for edits and adds.
    final ids = {for (final t in _txns.transactions) t.id};
    final before = _results.length;
    _results = _results.where((t) => ids.contains(t.id)).toList();
    if (_results.length != before) {
      _computeTotals();
      notifyListeners();
    }
    _refresh();
  }

  Future<void> _refresh() async {
    final requestNo = ++_requestNo;
    try {
      final rows = await _repo.search(_filter);
      if (requestNo != _requestNo) return; // a newer query is on its way
      // Keep only rows TransactionProvider still has (see above).
      final ids = {for (final t in _txns.transactions) t.id};
      _results = _txns.isLoading
          ? rows
          : rows.where((t) => ids.contains(t.id)).toList();
      _error = null;
    } catch (e) {
      if (requestNo != _requestNo) return;
      _error = 'Could not search transactions: $e';
      debugPrint(_error);
    }
    _computeTotals();
    _loading = false;
    notifyListeners();
  }

  void _computeTotals() {
    final (spent, income) = totalsOf(_results);
    _spentPaise = spent;
    _incomePaise = income;
  }

  /// (expense total, income total) in paise. Pure, so it can be unit-tested.
  static (int, int) totalsOf(List<TransactionModel> txns) {
    var spent = 0;
    var income = 0;
    for (final t in txns) {
      if (!t.counts) continue; // self transfers are never counted
      if (t.isExpense) {
        spent += t.amountPaise;
      } else {
        income += t.amountPaise;
      }
    }
    return (spent, income);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _txns.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
