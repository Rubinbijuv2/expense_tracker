import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/recurring_installment_repo.dart';
import '../data/recurring_payment_repo.dart';
import '../models/category_model.dart';
import '../models/recurring_installment.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../services/installment_schedule.dart';
import '../services/recurring_match.dart';
import '../services/recurring_action_service.dart';
import '../services/reminder_service.dart';
import 'transaction_provider.dart';

export 'recurring_queries.dart';

/// A repeat payment together with one of its pending installments
/// (used by the Home card and auto-match).
typedef UpcomingItem = DueItem;

/// Repeat payments (bills, EMI, chitti, fees) and their installments.
///
/// Money that is actually paid always becomes a normal transaction through
/// [TransactionProvider.add], so totals, budgets and charts include it.
class RecurringProvider extends ChangeNotifier {
  RecurringProvider(
    this._txns, {
    RecurringPaymentRepo? paymentRepo,
    RecurringInstallmentRepo? installmentRepo,
  }) : _repo = paymentRepo ?? RecurringPaymentRepo(),
       _instRepo = installmentRepo ?? RecurringInstallmentRepo() {
    _listenForNotificationActions();
  }

  final TransactionProvider _txns;
  final RecurringPaymentRepo _repo;
  final RecurringInstallmentRepo _instRepo;

  List<RecurringPayment> _items = [];
  Map<int, List<RecurringInstallment>> _installments = {};
  bool _loading = true;
  String? _error;
  Future<void>? _firstLoad;
  ReceivePort? _actionPort;

  bool get isLoading => _loading;
  String? get error => _error;
  List<RecurringPayment> get items => List.unmodifiable(_items);

  /// Every installment, by repeat payment id (read-only).
  Map<int, List<RecurringInstallment>> get allInstallments =>
      Map.unmodifiable(_installments);

  static DateTime get _today => InstallmentSchedule.dateOnly(DateTime.now());

  RecurringPayment? byId(int id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Installments of one item, oldest first.
  List<RecurringInstallment> installmentsOf(int id) =>
      List.unmodifiable(_installments[id] ?? const []);

  RecurringInstallment? nextPending(int id) =>
      InstallmentSchedule.nextPending(_installments[id] ?? const []);

  RecurringState stateOf(RecurringPayment p) =>
      InstallmentSchedule.stateOf(p, _installments[p.id] ?? const [], _today);

  RecurringProgress progressOf(RecurringPayment p) =>
      InstallmentSchedule.progressOf(p, _installments[p.id] ?? const []);

  /// Items grouped by type, in the order of [RecurringPayment.types].
  Map<String, List<RecurringPayment>> get byType => {
    for (final t in RecurringPayment.types)
      if (_items.any((p) => p.type == t))
        t: _items.where((p) => p.type == t).toList(),
  };

  // ---- Loading and generating installments ---------------------------------

  /// The first [load] (main.dart starts it). Notification taps wait for it.
  Future<void> ensureLoaded() => _firstLoad ??= load();

  /// Creates any missing installments, then reads everything again, and
  /// schedules the reminders again (PLAN.md 5.2: on app start and after
  /// every change).
  Future<void> load() async {
    try {
      _items = await _repo.getAll();
      for (final p in _items) {
        await _sync(p);
      }
      await _reloadInstallments();
      _error = null;
      _reschedule();
    } catch (e) {
      _error = 'Could not load repeat payments: $e';
      debugPrint(_error);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _reloadInstallments() async {
    final map = <int, List<RecurringInstallment>>{};
    for (final i in await _instRepo.getAll()) {
      map.putIfAbsent(i.recurringId, () => []).add(i);
    }
    _installments = map;
  }

  /// Adds installments from the start date up to the next upcoming one.
  /// If everything up to now is paid (for example the next one was paid
  /// early), one more is added so there is always something to pay next,
  /// unless the schedule has ended.
  Future<void> _sync(RecurringPayment p) async {
    if (!p.active || p.id == null) return;
    var existing = await _instRepo.getFor(p.id!);
    await _instRepo.insertPending(
      p.id!,
      InstallmentSchedule.missingDates(p, existing, _today),
    );
    existing = await _instRepo.getFor(p.id!);
    if (existing.any((i) => i.isPending)) return;
    var after = _today;
    if (existing.isNotEmpty && existing.last.dueDate.isAfter(after)) {
      after = existing.last.dueDate;
    }
    await _instRepo.insertPending(
      p.id!,
      InstallmentSchedule.missingDates(
        p,
        existing,
        after.add(const Duration(days: 1)),
      ),
    );
  }

  // ---- Add / edit / delete --------------------------------------------------

  /// Saves a new or edited item. After an edit, pending installments are
  /// made again from the new schedule; paid and skipped ones are kept.
  Future<void> save(RecurringPayment p) async {
    if (p.id == null) {
      await _repo.insert(p);
    } else {
      await _repo.update(p);
      await _instRepo.deletePending(p.id!);
    }
    await load();
  }

  Future<void> delete(RecurringPayment p) async {
    await _repo.delete(p.id!);
    await load();
    await _txns.load(); // their transactions lost the recurring_id link
  }

  // ---- Paying ----------------------------------------------------------------

  /// Marks [inst] as paid. With [addTransaction] a normal expense is created
  /// (today, the item's category and payment mode) and linked to it.
  Future<void> markPaid(
    RecurringPayment p,
    RecurringInstallment inst,
    int amountPaise, {
    bool addTransaction = true,
  }) async {
    final now = DateTime.now();
    int? txnId;
    if (addTransaction) {
      txnId = await _txns.add(
        RecurringActionService.paymentTransaction(p, inst, amountPaise, now),
      );
    }
    await _instRepo.update(inst.paid(amountPaise, txnId, now));
    await _afterChange(p);
  }

  /// Auto-match (PLAN.md 5.3): the user tapped "Mark Bike EMI as paid?" for
  /// an expense that is already saved. Links [txn] to the installment
  /// instead of creating a second expense.
  Future<void> linkPaid(
    RecurringPayment p,
    RecurringInstallment inst,
    TransactionModel txn,
  ) async {
    if (txn.recurringId != p.id) {
      await _txns.update(txn.copyWith(recurringId: p.id));
    }
    await _instRepo.update(inst.paid(txn.amountPaise, txn.id, DateTime.now()));
    await _afterChange(p);
  }

  /// Marks every pending installment due before today as paid at the usual
  /// amount, WITHOUT adding expenses (for payments made before using the app).
  /// Returns how many were marked.
  Future<int> markEarlierPaid(RecurringPayment p) async {
    final now = DateTime.now();
    var count = 0;
    for (final i in installmentsOf(p.id!)) {
      if (!i.isPending || !i.dueDate.isBefore(_today)) continue;
      await _instRepo.update(i.paid(p.amountPaise, null, now));
      count++;
    }
    await _afterChange(p);
    return count;
  }

  Future<void> skip(RecurringPayment p, RecurringInstallment inst) async {
    await _instRepo.update(inst.withStatus('skipped'));
    await _afterChange(p);
  }

  /// Back to pending. A paid one also has its linked expense deleted.
  Future<void> undo(RecurringPayment p, RecurringInstallment inst) async {
    final txnId = inst.transactionId;
    if (inst.isPaid && txnId != null) {
      final txn = _findTxn((t) => t.id == txnId);
      if (txn != null) await _txns.delete(txn);
    }
    await _instRepo.update(inst.withStatus('pending'));
    await _afterChange(p);
  }

  // ---- Chitti ----------------------------------------------------------------

  /// "I received the chitti": the lump sum becomes income in the
  /// "Chitti received" category and is shown on the chitti card.
  Future<void> chittiReceived(
    RecurringPayment p,
    int amountPaise,
    DateTime date,
  ) async {
    final category = _incomeCategory('Chitti received');
    if (category == null) throw StateError('No income category found');
    await _txns.add(
      TransactionModel(
        amountPaise: amountPaise,
        type: 'income',
        categoryId: category.id!,
        paymentMode: p.paymentMode,
        dateTime: date,
        merchant: p.organiserName ?? p.name,
        note: '${p.name} · chitti received',
        recurringId: p.id,
      ),
    );
    await _repo.setChittiReceived(p.id!, amountPaise, date);
    await load();
  }

  /// Undoes [chittiReceived]: clears it and deletes the income transaction.
  Future<void> undoChittiReceived(RecurringPayment p) async {
    final txn = _findTxn((t) => t.recurringId == p.id && t.type == 'income');
    if (txn != null) await _txns.delete(txn);
    await _repo.setChittiReceived(p.id!, null, null);
    await load();
  }

  // ---- Helpers ---------------------------------------------------------------

  Future<void> _afterChange(RecurringPayment p) async {
    await _sync(p);
    await _reloadInstallments();
    _reschedule();
    notifyListeners();
  }

  void _reschedule() =>
      ReminderService.instance.reschedule(_items, _installments);

  /// A reminder's "Mark as paid" ran in the background isolate; it posts
  /// to this mailbox so the open app reloads (see SmsActionService).
  void _listenForNotificationActions() {
    try {
      final port = ReceivePort();
      IsolateNameServer.removePortNameMapping(RecurringActionService.portName);
      IsolateNameServer.registerPortWithName(
        port.sendPort,
        RecurringActionService.portName,
      );
      port.listen((_) async {
        await _txns.load();
        await load();
      });
      _actionPort = port;
    } catch (e) {
      debugPrint('Could not listen for reminder actions: $e');
    }
  }

  TransactionModel? _findTxn(bool Function(TransactionModel) test) {
    for (final t in _txns.transactions) {
      if (test(t)) return t;
    }
    return null;
  }

  /// The income category called [name], else "Money received", else any.
  CategoryModel? _incomeCategory(String name) {
    final list = _txns.categoriesFor('income');
    for (final wanted in [name, 'Money received']) {
      for (final c in list) {
        if (c.name.toLowerCase() == wanted.toLowerCase()) return c;
      }
    }
    return list.isEmpty ? null : list.first;
  }

  @override
  void dispose() {
    _actionPort?.close();
    IsolateNameServer.removePortNameMapping(RecurringActionService.portName);
    super.dispose();
  }
}
