import 'package:flutter/foundation.dart';

import '../services/backup_service.dart';
import '../services/demo_data_service.dart';

// Screens catch this one to show the "not a valid backup" message.
export '../services/backup_service.dart' show InvalidBackupException;

/// Whole-database jobs for Settings: backup, restore, delete all data and
/// (developer rows) demo data. Screens call these instead of the services,
/// following screen → provider → service/repo → db_helper.
///
/// After restore, delete or demo data the screen calls `reloadAllData`
/// (settings/data_section.dart) so every provider reads the database again.
class DataProvider extends ChangeNotifier {
  DataProvider({BackupService? backupService, DemoDataService? demoService})
    : _backup = backupService ?? BackupService(),
      _demo = demoService ?? DemoDataService();

  final BackupService _backup;
  final DemoDataService _demo;

  /// Copies the database file and opens the share sheet.
  Future<void> backupAndShare() => _backup.backupAndShare();

  /// Replaces the database with a backup file. Throws
  /// [InvalidBackupException] when the file is not one of our backups.
  Future<void> restoreFromBytes(Uint8List bytes) =>
      _backup.restoreFromBytes(bytes);

  /// Empties every table and clears the saved data flags.
  Future<void> deleteAllData() => _backup.deleteAllData();

  /// Replaces all data with sample data. Returns how many transactions.
  Future<int> loadDemoData() => _demo.replaceWithDemoData();
}
