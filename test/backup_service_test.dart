import 'dart:io';

import 'package:expense_tracker/services/backup_service.dart';
import 'package:expense_tracker/services/budget_carry_over.dart';
import 'package:expense_tracker/services/recurring_suggester.dart';
import 'package:expense_tracker/services/sms_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delete all data clears saved flags (bug 2.5)', () {
    test('data flags are removed, settings stay', () async {
      SharedPreferences.setMockInitialValues({
        SmsService.scanDoneKey: true,
        BudgetCarryOver.doneKey: '2026-11',
        RecurringSuggester.dismissedKey: ['netflix'],
        'theme_mode': 'dark',
        'onboarding_done': true,
      });

      await BackupService.clearDataFlags();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(SmsService.scanDoneKey), isFalse);
      expect(prefs.containsKey(BudgetCarryOver.doneKey), isFalse);
      expect(prefs.containsKey(RecurringSuggester.dismissedKey), isFalse);
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getBool('onboarding_done'), isTrue);
    });
  });

  group('old backup copies are cleared (bug 2.6)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('backup_test_');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('deletes only backup copies', () async {
      final backups = [
        '${BackupService.backupPrefix}20261120_1305.db',
        '${BackupService.backupPrefix}20261121_0900.db',
      ];
      final others = ['report.pdf', 'transactions.csv', 'expense_tracker.db'];
      for (final name in [...backups, ...others]) {
        await File(p.join(dir.path, name)).writeAsString('x');
      }

      expect(await BackupService.clearOldBackups(dir), 2);

      final left = dir.listSync().map((e) => p.basename(e.path)).toSet();
      expect(left, others.toSet());
    });

    test('a missing folder is fine', () async {
      await dir.delete();
      expect(await BackupService.clearOldBackups(dir), 0);
    });
  });
}
