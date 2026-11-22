import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/data_provider.dart';
import '../../providers/detected_sms_provider.dart';
import '../../providers/own_accounts_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/repeat_suggestion_provider.dart';
import '../../providers/transaction_provider.dart';

/// After the database changed (restore, delete all, demo data), every
/// provider reads it again. History and Reports follow TransactionProvider
/// by themselves.
Future<void> reloadAllData(BuildContext context) async {
  final txns = context.read<TransactionProvider>();
  final detected = context.read<DetectedSmsProvider>();
  final budgets = context.read<BudgetProvider>();
  final dash = context.read<DashboardProvider>();
  final own = context.read<OwnAccountsProvider>();
  final recurring = context.read<RecurringProvider>();
  final suggestions = context.read<RepeatSuggestionProvider>();
  await txns.load();
  await detected.load();
  await budgets.load();
  await dash.loadBudget();
  await own.load();
  await recurring.load();
  await suggestions.loadDismissed();
}

/// Settings rows: Backup, Restore and Delete all data.
class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  // `context.read` gets the provider once, without rebuilding on changes.
  DataProvider get _data => context.read<DataProvider>();
  bool _busy = false;

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
      debugPrint('Data job failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // The DB is closed for the copy; the next query opens it again by itself.
  Future<void> _onBackup() => _run(_data.backupAndShare, '');

  Future<void> _onRestore() async {
    final data = _data; // read before any await
    final file = await FilePicker.pickFile(dialogTitle: 'Pick a backup file');
    if (file == null || !mounted) return; // user cancelled
    final ok = await _confirm(
      title: 'Restore this backup?',
      message:
          'All data now in the app will be replaced by "${file.name}". '
          'Your PIN and settings stay the same.',
      action: 'Restore',
    );
    if (!ok) return;
    await _run(() async {
      final bytes = await file.xFile.readAsBytes();
      await data.restoreFromBytes(bytes);
      if (mounted) await reloadAllData(context);
    }, 'Backup restored');
  }

  Future<void> _onDeleteAll() async {
    final data = _data;
    final ok = await _confirm(
      title: 'Delete all data?',
      message:
          'Every transaction, budget, detected SMS, custom category and '
          'learned merchant rule will be deleted. This cannot be undone.\n\n'
          'Tip: make a backup first. Your PIN and settings stay the same.',
      action: 'Delete everything',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await data.deleteAllData();
      if (mounted) await reloadAllData(context);
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
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
