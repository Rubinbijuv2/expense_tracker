import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';

/// Settings → Reminders: daily cash reminder on/off and its time.
class CashReminderSection extends StatelessWidget {
  const CashReminderSection({super.key});

  Future<void> _toggle(SettingsProvider settings, bool on) async {
    // Android 13+ shows nothing without the notification permission.
    if (on) await NotificationService.instance.requestPermission();
    await settings.setCashReminderOn(on);
  }

  Future<void> _pickTime(BuildContext context, SettingsProvider s) async {
    final time = await showTimePicker(
      context: context,
      initialTime: s.cashReminderTime,
      helpText: 'Daily cash reminder time',
    );
    if (time != null) await s.setCashReminderTime(time);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final on = settings.cashReminderOn;
    final time = settings.cashReminderTime.format(context); // e.g. 9:00 PM
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.payments_outlined),
          title: const Text('Daily cash reminder'),
          subtitle: Text(
            on ? '"Spent any cash today?" every day at $time' : 'Off',
          ),
          value: on,
          onChanged: (v) => _toggle(settings, v),
        ),
        ListTile(
          enabled: on,
          leading: const Icon(Icons.schedule),
          title: const Text('Reminder time'),
          subtitle: Text(time),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _pickTime(context, settings),
        ),
      ],
    );
  }
}
