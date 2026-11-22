import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../widgets/pin_pad.dart';

/// Covers the whole app until the right PIN (or fingerprint) is given.
///
/// It is drawn above the Navigator (see `builder:` in main.dart), so the
/// screen you were on stays open underneath and reappears after unlocking.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;
  Timer? _ticker; // refreshes the "try again in N s" countdown

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFingerprint());
    _startTickerIfNeeded();
  }

  Future<void> _tryFingerprint() async {
    final lock = context.read<AppLockProvider>();
    if (!lock.fingerprintEnabled || lock.lockoutSecondsLeft > 0) return;
    await lock.unlockWithFingerprint();
  }

  Future<void> _onPin(String pin) async {
    final lock = context.read<AppLockProvider>();
    final ok = await lock.unlockWithPin(pin);
    if (!mounted || ok) return;
    setState(
      () => _error = lock.lockoutSecondsLeft > 0
          ? 'Too many wrong tries.'
          : 'Wrong PIN. Try again.',
    );
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    if (_ticker != null) return;
    if (context.read<AppLockProvider>().lockoutSecondsLeft == 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final left = context.read<AppLockProvider>().lockoutSecondsLeft;
      setState(() {
        if (left == 0) {
          _error = null;
          t.cancel();
          _ticker = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    final wait = lock.lockoutSecondsLeft;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                const SizedBox(height: 16),
                PinPad(
                  title: 'Welcome back',
                  subtitle: 'Enter your PIN',
                  errorText: wait > 0
                      ? '${_error ?? ''} Try again in $wait s.'.trim()
                      : _error,
                  enabled: wait == 0,
                  onCompleted: _onPin,
                  onFingerprint: lock.fingerprintEnabled
                      ? _tryFingerprint
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
