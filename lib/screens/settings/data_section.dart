import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/backup_service.dart';

/// Settings rows: Backup, Restore and Delete all data.
class DataSection extends StatefulWidget {
  const DataSection({super.key, this.backupService});

  final BackupService? backupService;

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  late final BackupService _backup = widget.backupService ?? BackupService();
  bool _busy = false;

  /// After the database file changed, every provider reads it again.
  /// History and Reports follow TransactionProvider by themselves.
  Future<void> _reloadEverything() async {
    final txns = context.read<TransactionProvider>();
    final detected = context.read<DetectedSmsProvider>();
    final budgets = context.read<BudgetProvider>();
    final dash = context.read<DashboardProvider>();
    await txns.load();
    await detected.load();
    await budgets.load();
    await dash.loadBudget();
  }

  /// Runs [job] with a spinner and shows [done] or the error in a SnackBar.
  Future<void> _run(Future<void> Function() job, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await job();
      if (done.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(done)));
      }
    } on InvalidBackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // The DB is closed for the copy; the next query opens it again by itself.
  Future<void> _onBackup() => _run(_backup.backupAndShare, '');

  Future<void> _onRestore() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Pick a backup file');
    if (file == null || !mounted) return; // user cancelled
    final ok = await _confirm(
      title: 'Restore this backup?',
      message: 'All data now in the app will be replaced by "${file.name}". '
          'Your PIN and name stay the same.',
      action: 'Restore',
    );
    if (!ok) return;
    await _run(() async {
      final bytes = await file.xFile.readAsBytes();
      await _backup.restoreFromBytes(bytes);
      if (mounted) await _reloadEverything();
    }, 'Backup restored');
  }

  Future<void> _onDeleteAll() async {
    final ok = await _confirm(
      title: 'Delete all data?',
      message: 'Every transaction, budget, detected SMS, custom category and '
          'learned merchant rule will be deleted. This cannot be undone.\n\n'
          'Tip: make a backup first. Your PIN and name stay the same.',
      action: 'Delete everything',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await _backup.deleteAllData();
      if (mounted) await _reloadEverything();
    }, 'All data deleted');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool danger = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(danger ? Icons.warning_amber : Icons.restore),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup data'),
          subtitle: const Text('Save or send the database file'),
          onTap: _onBackup,
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.restore),
          title: const Text('Restore from backup'),
          subtitle: const Text('Pick a backup .db file'),
          onTap: _onRestore,
        ),
        ListTile(
          enabled: !_busy,
          leading: Icon(Icons.delete_forever_outlined, color: error),
          title: Text('Delete all data', style: TextStyle(color: error)),
          onTap: _onDeleteAll,
        ),
      ],
    );
  }
}
