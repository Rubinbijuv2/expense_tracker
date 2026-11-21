import 'package:flutter/material.dart';

import '../../services/demo_data_service.dart';
import 'data_section.dart';
import 'test_sms_screen.dart';

/// Hidden Settings rows, shown after tapping "Version" 5 times:
/// "Load demo data" (for the viva) and the Test SMS screen.
class DeveloperSection extends StatefulWidget {
  const DeveloperSection({super.key});

  @override
  State<DeveloperSection> createState() => _DeveloperSectionState();
}

class _DeveloperSectionState extends State<DeveloperSection> {
  bool _busy = false;

  Future<void> _loadDemo() async {
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
      final n = await DemoDataService().replaceWithDemoData();
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
          leading: const Icon(Icons.sms_outlined),
          title: const Text('Test SMS'),
          subtitle: const Text('Paste a bank SMS and see how it is read'),
          onTap: () => TestSmsScreen.open(context),
        ),
      ],
    );
  }
}
