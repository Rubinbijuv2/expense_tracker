import 'package:flutter/material.dart';

import '../../widgets/placeholder_body.dart';

/// Profile, theme, PIN, backup and restore.
/// Placeholder for now — built in step 10.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const PlaceholderBody(
        icon: Icons.settings_outlined,
        title: 'Settings',
        message: 'Profile, theme, PIN and backup options will appear here.',
      ),
    );
  }
}
