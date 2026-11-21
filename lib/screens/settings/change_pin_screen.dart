import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../widgets/pin_pad.dart';

/// Settings → Change PIN: current PIN first, then the new PIN twice.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  /// Returns true if the PIN was changed.
  static Future<bool?> open(BuildContext context) => Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const ChangePinScreen()));

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  bool _verified = false;
  String? _error;
  int _wrongTries = 0;

  Future<void> _checkOld(String pin) async {
    final ok = await context.read<AppLockProvider>().checkPin(pin);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _verified = true;
        _error = null;
      });
      return;
    }
    _wrongTries++;
    if (_wrongTries >= AppLockProvider.maxAttempts) {
      Navigator.pop(context, false); // stop guessing here
      return;
    }
    setState(() => _error = 'Wrong PIN. Try again.');
  }

  Future<void> _saveNew(String pin) async {
    await context.read<AppLockProvider>().savePin(pin);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _verified
              ? NewPinPad(onPinChosen: _saveNew)
              : PinPad(
                  title: 'Enter your current PIN',
                  errorText: _error,
                  onCompleted: _checkOld,
                ),
        ),
      ),
    );
  }
}
