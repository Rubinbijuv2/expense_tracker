import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/data_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../services/cash_reminder_service.dart';
import '../../services/reminder_service.dart';
import 'data_section.dart';
import 'test_sms_screen.dart';

/// Hidden Settings rows, shown after tapping "Version" 5 times:
/// "Load demo data" (for the viva), "Re-check pending SMS", Test SMS and
/// two reminder tests (fire now / in 1 minute) and a cash reminder test.
class DeveloperSection extends StatefulWidget {
  const DeveloperSection({super.key});

  @override
  State<DeveloperSection> createState() => _DeveloperSectionState();
}

class _DeveloperSectionState extends State<DeveloperSection> {
  bool _busy = false;

  Future<void> _loadDemo() async {
    final data = context.read<DataProvider>(); // read before any await
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber),
        title: const Text('Replace all data with demo data?'),
        content: const Text(
          'Every transaction, budget, detected SMS, custom category and '
          'merchant rule will be deleted, then about 3 months of sample '
          'data will be added.\n\nYour PIN and name stay the same.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final n = await data.loadDemoData();
      if (mounted) await reloadAllData(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Loaded $n demo transactions')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load demo data: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recheck() async {
    final messenger = ScaffoldMessenger.of(context);
    final detected = context.read<DetectedSmsProvider>();
    setState(() => _busy = true);
    try {
      final r = await detected.recheckPending();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${r.updated} cards fixed, ${r.removed} removed'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Re-check failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Test reminder for the soonest unpaid repeat payment (overdue first).
  Future<void> _testReminder({required bool now}) async {
    final messenger = ScaffoldMessenger.of(context);
    final due = context.read<RecurringProvider>().dueList;
    if (due.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a repeat payment first')),
      );
      return;
    }
    final d = due.first;
    try {
      if (now) {
        await ReminderService.instance.showTestNow(d.item, d.next);
      } else {
        await ReminderService.instance.scheduleTestInOneMinute(d.item, d.next);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Reminder for ${d.item.name} in about 1 minute '
              '(Android may delay it a little)',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Reminder failed: $e')));
    }
  }

  Future<void> _testCashReminder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CashReminderService.instance.showNow();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Reminder failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Load demo data'),
          subtitle: const Text('Replaces all data with sample transactions'),
          onTap: _loadDemo,
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.manage_search),
          title: const Text('Re-check pending SMS'),
          subtitle: const Text('Run the latest SMS rules on waiting cards'),
          onTap: _recheck,
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.sms_outlined),
          title: const Text('Test SMS / notification'),
          subtitle: const Text('Paste a bank SMS or payment app notification'),
          onTap: () => TestSmsScreen.open(context),
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Fire a reminder now'),
          subtitle: const Text('For the next unpaid repeat payment'),
          onTap: () => _testReminder(now: true),
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.alarm),
          title: const Text('Test reminder in 1 minute'),
          subtitle: const Text('Uses the same scheduling as real reminders'),
          onTap: () => _testReminder(now: false),
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Show cash reminder now'),
          subtitle: const Text('Tap it to open Add with mode = Cash'),
          onTap: _testCashReminder,
        ),
      ],
    );
  }
}
