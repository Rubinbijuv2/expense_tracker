part of 'detected_sms_provider.dart';

/// Actions from the Detected SMS screen (Save, Edit, Ignore, Merge …).
///
/// This is a `part` of detected_sms_provider.dart: Dart treats both files as
/// one library, so this extension can use the provider's private fields
/// (`_txns`, `_repo` …). Callers use them like normal methods:
/// `provider.save(sms)`.
extension DetectedSmsActions on DetectedSmsProvider {
  /// "Save": add the transaction with the guessed category, as it is.
  /// The screen opens Edit instead when there is no guess (the guessed
  /// category may have been deleted), so this is never called without one.
  /// Auto-match ("Mark Bike EMI as paid?") passes the repeat payment's
  /// [categoryId] and [recurringId]. Returns the saved transaction (with id).
  Future<TransactionModel> save(
    DetectedSms sms, {
    int? categoryId,
    int? recurringId,
  }) async {
    final category = categoryId ?? sms.guessedCategoryId;
    if (category == null) {
      throw StateError('Detected SMS ${sms.id} has no category');
    }
    final txn = DetectedSmsProvider.toTransaction(
      sms,
      category,
    ).copyWith(recurringId: recurringId);
    final id = await _txns.add(txn);
    await _finish(sms, 'saved');
    return txn.copyWith(id: id);
  }

  /// Save after "Edit". If the user picked a different category, learn a
  /// merchant rule so the next SMS from this merchant gets it automatically.
  /// Returns the saved transaction (with id).
  Future<TransactionModel> saveEdited(
    DetectedSms sms,
    TransactionModel txn,
  ) async {
    final saved = txn.copyWith(isSelfTransfer: sms.isSelfTransfer);
    final id = await _txns.add(saved);
    if (txn.categoryId != sms.guessedCategoryId) {
      await _learnRule(sms.merchant, txn.categoryId);
    }
    await _finish(sms, 'saved');
    return saved.copyWith(id: id);
  }

  Future<void> ignore(DetectedSms sms) => _finish(sms, 'ignored');

  /// Undo for [ignore].
  Future<void> restorePending(DetectedSms sms) async {
    await _repo.updateStatus(sms.id!, 'pending');
    await load();
  }

  Future<void> ignoreAll() async {
    final ids = _pending.map((s) => s.id!).toList();
    await _repo.ignoreAllPending();
    for (final id in ids) {
      await NotificationService.instance.cancelForSms(id);
    }
    await load();
  }

  /// "Always ignore this sender": future SMS from it are dropped by the
  /// parser, and its pending cards are removed now. Returns how many.
  Future<int> ignoreSender(String sender) async {
    await _ignoredRepo.add(sender);
    final ids = await _repo.ignorePendingFromSender(sender);
    for (final id in ids) {
      await NotificationService.instance.cancelForSms(id);
    }
    await load();
    return ids.length;
  }

  /// "Merge" (rule 12): one card that keeps the bank SMS's account and
  /// payment mode and the receipt's merchant and category. The receipt row
  /// is set aside (status 'ignored', still linked to the bank row).
  Future<void> merge(DetectedSms bank, DetectedSms receipt) async {
    await _repo.update(
      bank.copyWith(
        merchant: receipt.merchant,
        guessedCategoryId: receipt.guessedCategoryId,
        clearDuplicateOf: true,
      ),
    );
    await _repo.updateStatus(receipt.id!, 'ignored');
    await NotificationService.instance.cancelForSms(receipt.id!);
    await load();
  }

  /// "Not the same": show the two SMS as separate cards again.
  Future<void> unpair(DetectedSms a, DetectedSms b) async {
    await _repo.setDuplicateOf(a.id!, null);
    await _repo.setDuplicateOf(b.id!, null);
    await load();
  }

  Future<void> _finish(DetectedSms sms, String status) async {
    await _repo.updateStatus(sms.id!, status);
    await NotificationService.instance.cancelForSms(sms.id!);
    await load();
  }

  Future<void> _learnRule(String? merchant, int categoryId) async {
    final keyword = merchant?.trim().toLowerCase() ?? '';
    if (keyword.isEmpty || keyword == 'unknown') return;
    try {
      await _ruleRepo.upsert(keyword, categoryId);
    } catch (e) {
      debugPrint('Could not save merchant rule: $e');
    }
  }
}
