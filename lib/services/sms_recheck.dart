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
    final pending = (await _smsRepo.getPending()).reversed.toList();
    final ignored = await _ignoredRepo.getAll();
    var updated = 0;
    final removedIds = <int>[];

    // Pairs are rebuilt from scratch below.
    for (final sms in pending) {
      if (sms.duplicateOf != null) {
        await _smsRepo.setDuplicateOf(sms.id!, null);
      }
    }

    for (final old in pending) {
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
      final fresh = await _service.buildPending(
        parsed,
        old.receivedAt,
        id: old.id,
      );
      await _smsRepo.update(fresh);
      if (fresh.duplicateOf != null) {
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
