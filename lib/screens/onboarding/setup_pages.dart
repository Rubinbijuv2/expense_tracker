import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/pin_pad.dart';

/// Onboarding step: name and (optional) monthly budget.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onDone});

  /// budgetPaise is null when the budget field was left empty.
  final void Function(String name, int? budgetPaise) onDone;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _budget = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final text = _budget.text.trim();
    widget.onDone(_name.text.trim(), text.isEmpty ? null : parseToPaise(text));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About you',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly budget (optional)',
                prefixText: '₹ ',
                helperText: 'You can change it later from Home → Budgets',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final p = parseToPaise(v);
                if (p == null) return 'Enter a valid amount, e.g. 15000';
                if (p <= 0) return 'Budget must be more than ₹0';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _submit, child: const Text('Next')),
          ],
        ),
      ),
    );
  }
}

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
  late final Future<bool> _available =
      context.read<AppLockProvider>().auth.canUseBiometrics();

  Future<void> _enable() async {
    // Ask for the finger once, so we know it really works on this phone.
    final ok =
        await context.read<AppLockProvider>().auth.authenticateWithBiometrics();
    if (!mounted) return;
    if (ok) {
      widget.onDone(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fingerprint not confirmed. You can try again.')));
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
              Text('Unlock with fingerprint?',
                  style: Theme.of(context).textTheme.headlineSmall),
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

/// Last onboarding step: explain SMS detection, then ask Android.
class SmsPermissionPage extends StatelessWidget {
  const SmsPermissionPage({
    super.key,
    required this.saving,
    required this.onAllow,
    required this.onSkip,
  });

  final bool saving;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Center(child: Icon(Icons.sms_outlined, size: 80, color: scheme.primary)),
          const SizedBox(height: 24),
          Center(
            child: Text('Detect expenses from SMS',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 24),
          point(Icons.account_balance,
              'Only SMS from bank senders (like AX-HDFCBK) are read. '
              'Personal messages are skipped.'),
          point(Icons.cloud_off,
              'Everything stays on this phone. The app has no internet access.'),
          point(Icons.touch_app, 'Nothing is added until you tap Save.'),
          point(Icons.edit_note,
              'If you say no, you can still add everything by hand.'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onAllow,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Allow SMS access'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: saving ? null : onSkip,
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}
