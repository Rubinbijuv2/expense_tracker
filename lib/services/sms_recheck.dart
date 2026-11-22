import '../data/detected_sms_repo.dart';
import '../data/ignored_sender_repo.dart';
import '../models/detected_sms.dart';
import 'sms_parser.dart';
import 'sms_service.dart';

/// What [SmsRecheck.run] did.
class RecheckReport {
  final int updated;
  final List<int> removedIds;
  const RecheckReport({required this.updated, required this.removedIds});

  int get removed => removedIds.length;
}

/// Runs every pending card through today's SMS rules again.
///
/// Needed once after the version 2 parser update, because cards detected by
/// the old parser could be wrong (loyalty points, receipts shown as income).
class SmsRecheck {
  SmsRecheck({
    DetectedSmsRepo? smsRepo,
    IgnoredSenderRepo? ignoredRepo,
    SmsService? service,
  }) : _smsRepo = smsRepo ?? DetectedSmsRepo(),
       _ignoredRepo = ignoredRepo ?? IgnoredSenderRepo(),
       _service = service ?? SmsService();

  final DetectedSmsRepo _smsRepo;
  final IgnoredSenderRepo _ignoredRepo;
  final SmsService _service;

  /// Oldest first. Cards the rules now reject are DELETED, so their text is
  /// no longer stored; the others are updated in place (amount, type, kind,
  /// merchant, category, self transfer) and Bank + Receipt pairs are rebuilt.
  Future<RecheckReport> run() async {
    final all = (await _smsRepo.getPending()).reversed.toList();
    // Payment app notification cards are not SMS: the SMS rules would
    // reject them (not a bank sender), so they are left exactly as they are,
    // and so is the link of an SMS paired with one.
    final appIds = {
      for (final s in all)
        if (s.isNotification) s.id,
    };
    final pending = all.where((s) => !s.isNotification).toList();
    final ignored = await _ignoredRepo.getAll();
    var updated = 0;
    final removedIds = <int>[];

    // Pairs are rebuilt from scratch below (except pairs with a notification).
    for (final sms in pending) {
      if (sms.duplicateOf != null && !appIds.contains(sms.duplicateOf)) {
        await _smsRepo.setDuplicateOf(sms.id!, null);
      }
    }

    for (final old in pending) {
      final pairedWithApp = appIds.contains(old.duplicateOf);
      final parsed = SmsParser.parse(
        old.sender,
        old.body,
        ignoredSenders: ignored,
      );
      if (parsed == null) {
        await _smsRepo.delete(old.id!);
        removedIds.add(old.id!);
        continue;
      }
      var fresh = await _service.buildPending(
        parsed,
        old.receivedAt,
        id: old.id,
      );
      if (pairedWithApp) {
        fresh = fresh.isSelfTransfer
            ? fresh.copyWith(clearDuplicateOf: true)
            : fresh.copyWith(duplicateOf: old.duplicateOf);
      }
      await _smsRepo.update(fresh);
      if (fresh.duplicateOf != null && !pairedWithApp) {
        await _smsRepo.setDuplicateOf(fresh.duplicateOf!, fresh.id);
      }
      if (_changed(old, fresh)) updated++;
    }
    return RecheckReport(updated: updated, removedIds: removedIds);
  }

  static bool _changed(DetectedSms a, DetectedSms b) =>
      a.amountPaise != b.amountPaise ||
      a.type != b.type ||
      a.kind != b.kind ||
      a.merchant != b.merchant ||
      a.paymentMode != b.paymentMode ||
      a.accountLast4 != b.accountLast4 ||
      a.guessedCategoryId != b.guessedCategoryId ||
      a.isSelfTransfer != b.isSelfTransfer;
}
