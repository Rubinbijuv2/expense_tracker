import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../widgets/placeholder_body.dart';
import 'test_sms_screen.dart';

/// Profile, theme, PIN, backup and restore — built in step 10.
/// For now: the app version, and the hidden developer Test SMS screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const int _tapsNeeded = 5;
  int _versionTaps = 0;

  /// Tapping the version 5 times opens the developer screen
  /// (a common Android trick to hide developer options).
  void _onVersionTap() {
    _versionTaps++;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (_versionTaps >= _tapsNeeded) {
      _versionTaps = 0;
      TestSmsScreen.open(context);
    } else if (_versionTaps >= 2) {
      final left = _tapsNeeded - _versionTaps;
      messenger.showSnackBar(SnackBar(
        content: Text('$left more tap${left == 1 ? '' : 's'} to open Test SMS'),
        duration: const Duration(milliseconds: 800),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const PlaceholderBody(
            icon: Icons.settings_outlined,
            title: 'Settings',
            message: 'Profile, theme, PIN and backup options will appear here.',
          ),
          // kDebugMode is true only in `flutter run` builds, never in the
          // release APK, so this row is hidden from normal users.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('Test SMS (developer)'),
              subtitle: const Text('Shown in debug builds only'),
              onTap: () => TestSmsScreen.open(context),
            ),
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
