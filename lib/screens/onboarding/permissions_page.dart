import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/detected_sms_provider.dart';
import '../../services/notification_service.dart';
import '../../services/payment_notification_service.dart';
import '../../services/sms_service.dart';
import '../settings/payment_notifications_screen.dart';

/// Last onboarding step: SMS, notifications and (optional) payment app
/// notifications, each on its own card. Every card can be skipped; the
/// Finish button always works.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({
    super.key,
    required this.saving,
    required this.onFinish,
  });

  final bool saving;
  final VoidCallback onFinish;

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  bool _sms = false;
  bool _notifications = false;
  bool _paymentApps = false;

  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver tells us when the user comes back from
    // Android's settings, so the cards can show the new state.
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
    final sms = await SmsService.hasPermission();
    var notifications = false;
    var paymentApps = false;
    try {
      notifications = await Permission.notification.isGranted;
      paymentApps =
          await PaymentNotificationService.isEnabled() &&
          await PaymentNotificationService.hasAccess();
    } catch (e) {
      debugPrint('Could not check permissions: $e');
    }
    if (!mounted) return;
    setState(() {
      _sms = sms;
      _notifications = notifications;
      _paymentApps = paymentApps;
    });
  }

  Future<void> _allowSms() async {
    await context.read<DetectedSmsProvider>().requestPermission();
    await _refresh();
  }

  Future<void> _allowNotifications() async {
    await NotificationService.instance.requestPermission();
    await _refresh();
  }

  Future<void> _turnOnPaymentApps() async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await PaymentNotificationsScreen.open(context);
    await _refresh();
    if (granted != true) {
      messenger.showSnackBar(const SnackBar(content: Text('Access not given')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Permissions', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Everything stays on this phone. You can change these later in '
          'Settings, and you can always add expenses by hand.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _PermissionCard(
          icon: Icons.sms_outlined,
          title: 'Detect expenses from SMS',
          text:
              'Only SMS from bank senders (like AX-HDFCBK) are read. '
              'Personal messages are skipped. Nothing is added until you '
              'tap Save.',
          granted: _sms,
          buttonLabel: 'Allow',
          onPressed: _allowSms,
        ),
        _PermissionCard(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          text: 'For detected payments, budget alerts and bill reminders.',
          granted: _notifications,
          buttonLabel: 'Allow',
          onPressed: _allowNotifications,
        ),
        _PermissionCard(
          icon: Icons.notifications_active_outlined,
          title: 'Read payment app notifications',
          optional: true,
          text:
              'Find payments in Google Pay, PhonePe, Paytm, BHIM, CRED and '
              'Amazon notifications. Useful when the bank SMS is late.',
          granted: _paymentApps,
          buttonLabel: 'Turn on',
          onPressed: _turnOnPaymentApps,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.saving ? null : widget.onFinish,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: widget.saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Finish'),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.granted,
    required this.buttonLabel,
    required this.onPressed,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool granted;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  if (optional)
                    Text(
                      'Optional',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(text, style: textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: granted
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Allowed',
                                style: textTheme.labelLarge?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          )
                        : OutlinedButton(
                            onPressed: onPressed,
                            child: Text(buttonLabel),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
