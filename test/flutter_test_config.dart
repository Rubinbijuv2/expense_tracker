import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `flutter test` runs this file automatically before every test file in
/// this folder (it must be named exactly `flutter_test_config.dart`).
///
/// On a phone, sqflite talks to Android's SQLite. Tests run on the computer,
/// where that plugin doesn't exist, so here we use `sqflite_common_ffi`:
/// the same sqflite API backed by a desktop SQLite library. Without this,
/// widget tests print "databaseFactory not initialized".
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  // "NoIsolate" runs SQLite on the test's own thread. Widget tests use a
  // fake clock that only moves when the test pumps, and this keeps database
  // calls working inside it.
  databaseFactory = databaseFactoryFfiNoIsolate;

  // Every test file gets its own empty temp folder for the database file,
  // so files running in parallel never share a database, and nothing is
  // written inside the project.
  final dir = Directory.systemTemp.createTempSync('expense_tracker_test_');
  await databaseFactory.setDatabasesPath(dir.path);
  tearDownAll(() async {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold the file open for a moment; the OS cleans
      // its temp folder later anyway.
    }
  });

  await testMain();
}
