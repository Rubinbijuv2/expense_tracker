import '../data/category_repo.dart';
import '../data/detected_sms_repo.dart';
import '../data/merchant_rule_repo.dart';
import '../data/own_account_repo.dart';
import '../models/category_model.dart';
import '../models/detected_sms.dart';
import 'category_guesser.dart';
import 'self_transfer.dart';
import 'sms_parser.dart';

/// Turns a parsed SMS into a pending detected_sms row: category guess
/// (rule 10), self transfer (rule 13) and Bank + Receipt partner (rule 12).
/// Used by [SmsService.buildPending].
class SmsPendingBuilder {
  SmsPendingBuilder(
    this._smsRepo, {
    MerchantRuleRepo? ruleRepo,
    CategoryRepo? categoryRepo,
    OwnAccountRepo? ownRepo,
  }) : _ruleRepo = ruleRepo ?? MerchantRuleRepo(),
       _categoryRepo = categoryRepo ?? CategoryRepo(),
       _ownRepo = ownRepo ?? OwnAccountRepo();

  final DetectedSmsRepo _smsRepo;
  final MerchantRuleRepo _ruleRepo;
  final CategoryRepo _categoryRepo;
  final OwnAccountRepo _ownRepo;

  /// Bank + Receipt pairing window (also [SmsService.pairWindow]).
  static const Duration pairWindow = Duration(minutes: 30);

  Future<DetectedSms> build(
    ParsedSms parsed,
    DateTime receivedAt, {
    int? id,
  }) async {
    final isSelf = SelfTransfer.detect(
      parsed.body,
      parsed.accountLast4,
      await _ownRepo.getAllLast4(),
    );
    return DetectedSms(
      id: id,
      sender: parsed.sender,
      body: parsed.body,
      amountPaise: parsed.amountPaise,
      type: parsed.type,
      merchant: parsed.merchant,
      accountLast4: parsed.accountLast4,
      paymentMode: parsed.paymentMode,
      guessedCategoryId: await _guessCategoryId(parsed),
      receivedAt: receivedAt,
      kind: parsed.kind,
      isSelfTransfer: isSelf,
      duplicateOf: isSelf ? null : await _findPartnerId(parsed, receivedAt),
    );
  }

  /// Rule 12: a pending SMS of the other kind (bank ↔ receipt) with the
  /// same amount and type within 30 minutes. 'check' SMS are never paired.
  /// A payment app notification counts as a receipt (section 7.5).
  Future<int?> _findPartnerId(ParsedSms parsed, DateTime at) async {
    final other = switch (parsed.kind) {
      'bank' => 'receipt',
      'receipt' => 'bank',
      _ => null,
    };
    if (other == null) return null;
    final partner = await _smsRepo.findPairPartner(
      parsed.amountPaise,
      other,
      parsed.type,
      at,
      window: pairWindow,
    );
    return partner?.id;
  }

  /// Rule 10, plus a safety net: the guessed category must match the type.
  /// Income falls back to 'Money received' (or any income category);
  /// expense falls back to 'Others'.
  Future<int?> _guessCategoryId(ParsedSms parsed) async {
    final guess = CategoryGuesser.guessSms(parsed, await _ruleRepo.getAll());
    CategoryModel? category = guess.isFromRule
        ? await _categoryRepo.getById(guess.categoryId!)
        : await _categoryRepo.getByName(guess.categoryName!);

    if (category == null || category.type != parsed.type) {
      if (parsed.type == 'income') {
        category = await _categoryRepo.getByName(
          CategoryGuesser.incomeFallback,
        );
        if (category == null) {
          final incomeCats = await _categoryRepo.getByType('income');
          category = incomeCats.isEmpty ? null : incomeCats.first;
        }
      } else {
        category = await _categoryRepo.getByName(CategoryGuesser.fallback);
      }
    }
    return category?.id;
  }
}
