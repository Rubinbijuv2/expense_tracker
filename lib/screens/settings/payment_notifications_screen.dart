import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/payment_notification_service.dart';

/// Settings → "Read payment app notifications" switch (PLAN.md 7.2).
///
/// It is ON only when the saved switch is on AND Android's Notification
/// access is still given (the user can remove access in Android settings at
/// any time, so it is checked again whenever the app comes back).
class PaymentNotificationsTile extends StatefulWidget {
  const PaymentNotificationsTile({super.key});

  @override
  State<PaymentNotificationsTile> createState() =>
      _PaymentNotificationsTileState();
}

class _PaymentNotificationsTileState extends State<PaymentNotificationsTile>
    with WidgetsBindingObserver {
  bool _on = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await PaymentNotificationService.isEnabled();
    final access = await PaymentNotificationService.hasAccess();
    // Access was removed in Android settings: switch off for real.
    if (enabled && !access) await PaymentNotificationService.setEnabled(false);
    if (!mounted) return;
    setState(() {
      _on = enabled && access;
      _busy = false;
    });
  }

  Future<void> _turnOn() async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await PaymentNotificationsScreen.open(context);
    await _refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          granted == true
              ? 'Payment app notifications are on'
              : 'Access not given',
        ),
      ),
    );
  }

  Future<void> _turnOff() async {
    final messenger = ScaffoldMessenger.of(context);
    await PaymentNotificationService.setEnabled(false);
    await _refresh();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Stopped reading payment app notifications. You can also remove '
          'access in Android settings.',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open',
          onPressed: PaymentNotificationService.openAccessSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Read payment app notifications'),
      subtitle: const Text(
        'Google Pay, PhonePe, Paytm, BHIM, CRED and Amazon only',
      ),
      value: _on,
      onChanged: _busy ? null : (on) => on ? _turnOn() : _turnOff(),
    );
  }
}

/// The explanation shown before turning the feature on (PLAN.md 7.2).
/// Returns true (by Navigator.pop) if access was given.
class PaymentNotificationsScreen extends StatefulWidget {
  const PaymentNotificationsScreen({super.key});

  static Future<bool?> open(BuildContext context) => Navigator.of(context)
      .push<bool>(
        MaterialPageRoute(builder: (_) => const PaymentNotificationsScreen()),
      );

  @override
  State<PaymentNotificationsScreen> createState() =>
      _PaymentNotificationsScreenState();
}

class _PaymentNotificationsScreenState extends State<PaymentNotificationsScreen>
    with WidgetsBindingObserver {
  /// True after "Open settings", until the user comes back to the app.
  bool _waitingForReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user came back from Android's settings page: check the answer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForReturn) {
      _waitingForReturn = false;
      _finish();
    }
  }

  Future<void> _openSettings() async {
    // Already allowed earlier (e.g. switched off and on again).
    if (await PaymentNotificationService.hasAccess()) {
      await _finish();
      return;
    }
    _waitingForReturn = true;
    final opened = await PaymentNotificationService.openAccessSettings();
    if (!opened && mounted) {
      _waitingForReturn = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Android settings')),
      );
    }
  }

  Future<void> _finish() async {
    final granted = await PaymentNotificationService.hasAccess();
    await PaymentNotificationService.setEnabled(granted);
    if (mounted) Navigator.of(context).pop(granted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment app notifications')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Expense Tracker will read notifications ONLY from Google Pay, '
            'PhonePe, Paytm, BHIM, CRED and Amazon, only to find payments. '
            'Nothing leaves your phone.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Notifications from every other app are ignored and never '
            'stored. Payments found this way appear on the Detected screen '
            'with an "App" label, just like bank SMS. SMS detection stays on '
            'as the main source.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'On the next page, turn on "Expense Tracker", then come back.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open settings'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Switch greyed out?'),
              subtitle: const Text(
                'Android 13+ blocks this for apps installed from an APK. '
                'Open App info → ⋮ (top right) → "Allow restricted settings", '
                'then tap Open settings again.',
              ),
              trailing: TextButton(
                onPressed: openAppSettings, // from permission_handler
                child: const Text('App info'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
