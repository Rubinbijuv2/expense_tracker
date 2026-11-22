part of 'recurring_provider.dart';

/// Paying installments and the chitti lump sum.
///
/// A `part` of recurring_provider.dart (same library), so this extension can
/// use the provider's private fields. Callers use them like normal methods:
/// `recurring.markPaid(...)`.
extension RecurringActions on RecurringProvider {
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
    final today = RecurringProvider._today;
    for (final i in installmentsOf(p.id!)) {
      if (!i.isPending || !i.dueDate.isBefore(today)) continue;
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
}
