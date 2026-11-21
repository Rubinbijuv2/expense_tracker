import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/detected_sms_repo.dart';
import '../data/ignored_sender_repo.dart';
import '../data/merchant_rule_repo.dart';
import '../models/detected_sms.dart';
import '../models/transaction_model.dart';
import '../services/notification_service.dart';
import '../services/sms_action_service.dart';
import '../services/sms_recheck.dart';
import '../services/sms_service.dart';
import 'transaction_provider.dart';

/// Pending detected SMS + whether SMS detection is switched on.
///
/// `with WidgetsBindingObserver` lets this class hear when the app comes
/// back to the screen, so it can reload SMS saved by the background handler
/// and re-check the permission (the user may have changed it in Settings).
class DetectedSmsProvider extends ChangeNotifier with WidgetsBindingObserver {
  DetectedSmsProvider(
    this._txns, {
    DetectedSmsRepo? smsRepo,
    MerchantRuleRepo? ruleRepo,
    IgnoredSenderRepo? ignoredRepo,
    SmsService? smsService,
  }) : _repo = smsRepo ?? DetectedSmsRepo(),
       _ruleRepo = ruleRepo ?? MerchantRuleRepo(),
       _ignoredRepo = ignoredRepo ?? IgnoredSenderRepo(),
       _service = smsService ?? SmsService();

  final TransactionProvider _txns;
  final DetectedSmsRepo _repo;
  final MerchantRuleRepo _ruleRepo;
  final IgnoredSenderRepo _ignoredRepo;
  final SmsService _service;

  static const String _askedKey = 'sms_permission_asked';
  static const String _recheckKey = 'sms_v2_recheck_done';

  List<DetectedSms> _pending = [];
  bool _permissionChecked = false;
  bool _smsEnabled = false;
  bool _listening = false;
  bool _loading = true;
  Future<void>? _started;
  ReceivePort? _actionPort;

  /// Pending suggestions, newest first.
  List<DetectedSms> get pending => List.unmodifiable(_pending);

  /// Pending suggestions as cards: one SMS, or a Bank + Receipt pair.
  List<List<DetectedSms>> get cards => groupPairs(_pending);
  bool get smsEnabled => _smsEnabled;

  /// True until the pending list has been read the first time.
  bool get isLoading => _loading;

  /// Home shows the "Turn on SMS detection" banner when this is true.
  bool get showPermissionBanner => _permissionChecked && !_smsEnabled;

  /// Called once from main.dart. Safe to call again (returns the same work).
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    WidgetsBinding.instance.addObserver(this);
    _listenForNotificationActions();
    await _recheckOnce();
    await load();
    await _refreshPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      _txns.load(); // a notification's Save button may have added one
      _refreshPermission();
    }
  }

  /// The notification Save / Ignore buttons run in a background isolate;
  /// it posts the SMS id to this mailbox so the open app refreshes at once.
  void _listenForNotificationActions() {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(SmsActionService.portName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      SmsActionService.portName,
    );
    port.listen((_) {
      load();
      _txns.load();
    });
    _actionPort = port;
  }

  /// After the v2 parser update, old pending cards are checked again once.
  Future<void> _recheckOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_recheckKey) ?? false) return;
      final report = await recheckPending(reload: false);
      await prefs.setBool(_recheckKey, true);
      debugPrint(
        'Pending SMS re-checked: ${report.updated} updated, '
        '${report.removed} removed',
      );
    } catch (e) {
      debugPrint('Could not re-check pending SMS: $e');
    }
  }

  /// Developer button too: runs today's rules on every pending card.
  Future<RecheckReport> recheckPending({bool reload = true}) async {
    final report = await SmsRecheck(service: _service).run();
    for (final id in report.removedIds) {
      await NotificationService.instance.cancelForSms(id);
    }
    if (reload) await load();
    return report;
  }

  Future<void> load() async {
    try {
      _pending = await _repo.getPending();
    } catch (e) {
      debugPrint('Could not load detected SMS: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _refreshPermission() async {
    _smsEnabled = await SmsService.hasPermission();
    _permissionChecked = true;
    notifyListeners();
    if (_smsEnabled) await _startDetection();
  }

  /// Starts the listener once, then scans the inbox (only the first time ever).
  Future<void> _startDetection() async {
    if (_listening) return;
    _listening = true;
    try {
      // handleIncoming already showed the notification; just refresh Home.
      _service.startListening((_) => load());
      final found = await _service.scanInboxOnce();
      await NotificationService.instance.showScanSummary(found);
      await load();
    } catch (e) {
      debugPrint('Could not start SMS detection: $e');
    }
  }

  /// True only on the very first launch, when permission is not yet granted.
  /// Home uses it to show the explanation dialog once.
  Future<bool> shouldAskOnFirstLaunch() async {
    await start();
    if (_smsEnabled) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return false;
      await prefs.setBool(_askedKey, true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Onboarding already explained SMS detection, so Home must not ask again.
  Future<void> markPermissionAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
    } catch (e) {
      debugPrint('Could not save SMS asked flag: $e');
    }
  }

  /// After the user agreed in our explanation dialog: ask Android.
  Future<void> requestPermission() async {
    try {
      await SmsService.requestPermission();
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    await _refreshPermission();
  }

  /// Developer Test SMS screen: treats the text exactly like a new SMS
  /// arriving now (same SmsService.handleIncoming as real SMS).
  Future<SmsResult> simulateIncoming(String sender, String body) async {
    final result = await _service.handleIncoming(sender, body, DateTime.now());
    await load();
    return result;
  }

  // ---- Actions from the Detected SMS screen -----------------------------

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
    final txn = toTransaction(sms, category).copyWith(recurringId: recurringId);
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

  /// The transaction a detected SMS becomes.
  static TransactionModel toTransaction(DetectedSms sms, int categoryId) =>
      SmsActionService.toTransaction(sms, categoryId);

  /// Pure helper (unit-tested): each pending SMS becomes its own card,
  /// except a Bank + Receipt pair that point to each other, which becomes
  /// one card [bank, receipt] at the place of the newer of the two.
  static List<List<DetectedSms>> groupPairs(List<DetectedSms> pending) {
    final byId = {for (final s in pending) s.id: s};
    final used = <int?>{};
    final cards = <List<DetectedSms>>[];
    for (final s in pending) {
      if (used.contains(s.id)) continue;
      final other = byId[s.duplicateOf];
      if (other != null &&
          other.duplicateOf == s.id &&
          !used.contains(other.id)) {
        used.addAll([s.id, other.id]);
        cards.add(s.kind == 'bank' ? [s, other] : [other, s]);
      } else {
        used.add(s.id);
        cards.add([s]);
      }
    }
    return cards;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionPort?.close();
    IsolateNameServer.removePortNameMapping(SmsActionService.portName);
    super.dispose();
  }
}
