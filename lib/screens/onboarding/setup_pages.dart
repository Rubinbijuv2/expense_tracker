import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../widgets/pin_pad.dart';

/// Onboarding step: choose the PIN and type it twice.
class PinSetupPage extends StatelessWidget {
  const PinSetupPage({super.key, required this.onDone});

  final ValueChanged<String> onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: NewPinPad(onPinChosen: onDone),
      ),
    );
  }
}

/// Onboarding step: turn on fingerprint unlock (only if the phone has one).
class FingerprintPage extends StatefulWidget {
  const FingerprintPage({super.key, required this.onDone});

  final ValueChanged<bool> onDone;

  @override
  State<FingerprintPage> createState() => _FingerprintPageState();
}

class _FingerprintPageState extends State<FingerprintPage> {
  late final Future<bool> _available = context
      .read<AppLockProvider>()
      .auth
      .canUseBiometrics();

  Future<void> _enable() async {
    // Ask for the finger once, so we know it really works on this phone.
    final ok = await context
        .read<AppLockProvider>()
        .auth
        .authenticateWithBiometrics();
    if (!mounted) return;
    if (ok) {
      widget.onDone(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint not confirmed. You can try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // FutureBuilder shows one thing while a Future is running and
    // rebuilds with its result when it finishes.
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final available = snap.data!;
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.fingerprint, size: 96, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                'Unlock with fingerprint?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                available
                    ? 'Use your fingerprint instead of typing the PIN. '
                          'The PIN still works too.'
                    : 'No fingerprint is set up on this phone. You can turn '
                          'this on later in Settings.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (available)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _enable,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => widget.onDone(false),
                  child: Text(available ? 'Skip' : 'Next'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
