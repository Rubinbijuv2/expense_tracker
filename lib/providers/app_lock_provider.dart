import 'package:flutter/widgets.dart';

import '../services/auth_service.dart';

/// Decides when the lock screen covers the app.
///
/// - Locked on every app start (if a PIN exists).
/// - Locked again when the app comes back after [relockAfter] or more
///   in the background.
/// - Wrong PIN 5 times → wait 30 seconds before the next try.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppLockProvider({
    required bool pinSet,
    required this._fingerprintEnabled,
    AuthService? auth,
    DateTime Function()? clock,
  }) : _pinSet = pinSet,
       _locked = pinSet,
       _auth = auth ?? AuthService(),
       _now = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  static const Duration relockAfter = Duration(minutes: 1);
  static const int maxAttempts = 5;
  static const Duration lockoutTime = Duration(seconds: 30);

  final AuthService _auth;
  final DateTime Function() _now;

  bool _pinSet;
  bool _locked;
  bool _fingerprintEnabled;
  DateTime? _backgroundSince;
  int _failedAttempts = 0;
  DateTime? _lockedOutUntil;

  bool get isLocked => _locked;
  bool get fingerprintEnabled => _fingerprintEnabled;
  AuthService get auth => _auth;

  /// Reads the PIN/fingerprint state from secure storage (before runApp).
  static Future<AppLockProvider> load() async {
    final auth = AuthService();
    return AppLockProvider(
      pinSet: await auth.hasPin(),
      fingerprintEnabled: await auth.isFingerprintEnabled(),
      auth: auth,
    );
  }

  /// Seconds left before PIN entry is allowed again (0 = allowed now).
  int get lockoutSecondsLeft {
    final until = _lockedOutUntil;
    if (until == null) return 0;
    final left = until.difference(_now()).inSeconds;
    return left > 0 ? left + 1 : 0;
  }

  // ---- App going to / coming from the background --------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundSince ??= _now();
      case AppLifecycleState.resumed:
        final since = _backgroundSince;
        _backgroundSince = null;
        if (since != null && shouldRelock(since, _now())) lock();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Pure rule, unit-tested: lock if the app was away for 1 minute or more.
  static bool shouldRelock(DateTime backgroundSince, DateTime now) =>
      now.difference(backgroundSince) >= relockAfter;

  /// While locked, the Android back button does nothing (it must not close
  /// screens hidden behind the lock).
  @override
  Future<bool> didPopRoute() async => _locked;

  void lock() {
    if (!_pinSet || _locked) return;
    _locked = true;
    notifyListeners();
  }

  // ---- Unlocking -----------------------------------------------------------

  /// Checks the typed PIN. Returns true and unlocks if it is right.
  Future<bool> unlockWithPin(String pin) async {
    if (lockoutSecondsLeft > 0) return false;
    final ok = await _auth.verifyPin(pin);
    if (ok) {
      _failedAttempts = 0;
      _lockedOutUntil = null;
      _locked = false;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= maxAttempts) {
        _failedAttempts = 0;
        _lockedOutUntil = _now().add(lockoutTime);
      }
    }
    notifyListeners();
    return ok;
  }

  Future<bool> unlockWithFingerprint() async {
    if (!_fingerprintEnabled) return false;
    final ok = await _auth.authenticateWithBiometrics();
    if (ok) {
      _failedAttempts = 0;
      _lockedOutUntil = null;
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  // ---- Setup and Settings ----------------------------------------------------

  /// Onboarding and "Change PIN" both save the PIN through here.
  Future<void> savePin(String pin) async {
    await _auth.setPin(pin);
    _pinSet = true;
    notifyListeners();
  }

  Future<bool> checkPin(String pin) => _auth.verifyPin(pin);

  Future<void> setFingerprintEnabled(bool on) async {
    await _auth.setFingerprintEnabled(on);
    _fingerprintEnabled = on;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
