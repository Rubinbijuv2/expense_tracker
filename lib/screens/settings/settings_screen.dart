import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import 'change_pin_screen.dart';
import 'data_section.dart';
import 'developer_section.dart';

/// Profile, theme, PIN/fingerprint, categories, budgets, backup and reset.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const int _tapsNeeded = 5;
  int _versionTaps = 0;
  bool _devUnlocked = false;
  Future<bool>? _biometricsAvailable;

  @override
  void initState() {
    super.initState();
    _biometricsAvailable = context
        .read<AppLockProvider>()
        .auth
        .canUseBiometrics();
  }

  /// Tapping the version 5 times shows the Developer section (Load demo
  /// data, Test SMS) — a common Android trick to hide developer options.
  void _onVersionTap() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (_devUnlocked) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Developer options are shown above'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    _versionTaps++;
    if (_versionTaps >= _tapsNeeded) {
      setState(() => _devUnlocked = true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Developer options unlocked')),
      );
    } else if (_versionTaps >= 2) {
      final left = _tapsNeeded - _versionTaps;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$left more tap${left == 1 ? '' : 's'} to unlock '
            'developer options',
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _editName(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) await settings.setName(name);
  }

  Future<void> _changePin() async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await ChangePinScreen.open(context);
    if (changed == true) {
      messenger.showSnackBar(const SnackBar(content: Text('PIN changed')));
    } else if (changed == false) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Too many wrong tries. PIN not changed.')),
      );
    }
  }

  Future<void> _toggleFingerprint(AppLockProvider lock, bool on) async {
    if (on && !await lock.auth.authenticateWithBiometrics()) return;
    await lock.setFingerprintEnabled(on);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final lock = context.watch<AppLockProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Profile'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Name'),
            subtitle: Text(settings.name.isEmpty ? 'Not set' : settings.name),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editName(settings),
          ),
          const _Header('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.phone_android),
                  label: Text('System'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const _Header('Security'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            onTap: _changePin,
          ),
          FutureBuilder<bool>(
            future: _biometricsAvailable,
            builder: (context, snap) {
              final available = snap.data ?? false;
              return SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Unlock with fingerprint'),
                subtitle: available
                    ? null
                    : const Text('No fingerprint set up on this phone'),
                value: lock.fingerprintEnabled && available,
                onChanged: available
                    ? (on) => _toggleFingerprint(lock, on)
                    : null,
              );
            },
          ),
          const _Header('Money'),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Budgets'),
            onTap: () => BudgetsScreen.open(context, DateTime.now()),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage categories'),
            onTap: () => CategoriesScreen.open(context),
          ),
          const _Header('Data'),
          const DataSection(),
          // kDebugMode is true only in `flutter run` builds, so while
          // developing the section is always there; in the release APK it
          // appears only after tapping Version 5 times.
          if (kDebugMode || _devUnlocked) ...[
            const _Header('Developer'),
            const DeveloperSection(),
          ],
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text(AppConstants.appVersion),
            onTap: _onVersionTap,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
