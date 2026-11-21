import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/detected_sms_repo.dart';
import '../data/merchant_rule_repo.dart';
import '../models/detected_sms.dart';
import '../models/transaction_model.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';
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
    SmsService? smsService,
  })  : _repo = smsRepo ?? DetectedSmsRepo(),
        _ruleRepo = ruleRepo ?? MerchantRuleRepo(),
        _service = smsService ?? SmsService();

  final TransactionProvider _txns;
  final DetectedSmsRepo _repo;
  final MerchantRuleRepo _ruleRepo;
  final SmsService _service;

  static const String _askedKey = 'sms_permission_asked';

  List<DetectedSms> _pending = [];
  bool _permissionChecked = false;
  bool _smsEnabled = false;
  bool _listening = false;
  Future<void>? _started;

  /// Pending suggestions, newest first.
  List<DetectedSms> get pending => List.unmodifiable(_pending);
  bool get smsEnabled => _smsEnabled;

  /// Home shows the "Turn on SMS detection" banner when this is true.
  bool get showPermissionBanner => _permissionChecked && !_smsEnabled;

  /// Called once from main.dart. Safe to call again (returns the same work).
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    WidgetsBinding.instance.addObserver(this);
    await load();
    await _refreshPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      _refreshPermission();
    }
  }

  Future<void> load() async {
    try {
      _pending = await _repo.getPending();
    } catch (e) {
      debugPrint('Could not load detected SMS: $e');
    }
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
    final result =
        await _service.handleIncoming(sender, body, DateTime.now());
    await load();
    return result;
  }

  // ---- Actions from the Detected SMS screen -----------------------------

  /// "Save": add the transaction with the guessed category, as it is.
  Future<void> save(DetectedSms sms) async {
    await _txns.add(toTransaction(sms, sms.guessedCategoryId!));
    await _finish(sms, 'saved');
  }

  /// Save after "Edit". If the user picked a different category, learn a
  /// merchant rule so the next SMS from this merchant gets it automatically.
  Future<void> saveEdited(DetectedSms sms, TransactionModel txn) async {
    await _txns.add(txn);
    if (txn.categoryId != sms.guessedCategoryId) {
      await _learnRule(sms.merchant, txn.categoryId);
    }
    await _finish(sms, 'saved');
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
      TransactionModel(
        amountPaise: sms.amountPaise,
        type: sms.type,
        categoryId: categoryId,
        paymentMode: sms.paymentMode ?? AppConstants.defaultPaymentMode,
        dateTime: sms.receivedAt,
        merchant: sms.merchant,
        source: 'sms',
        smsId: sms.id,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
