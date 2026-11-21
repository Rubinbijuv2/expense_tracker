import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/providers/app_lock_provider.dart';
import 'package:expense_tracker/services/auth_service.dart';

/// Stand-in for flutter_secure_storage, kept in memory.
class MemoryStore implements SecureStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

void main() {
  group('AuthService PIN', () {
    late MemoryStore store;
    late AuthService auth;

    setUp(() {
      store = MemoryStore();
      auth = AuthService(store: store);
    });

    test('hashPin is SHA-256 hex and depends on salt and PIN', () {
      final h = AuthService.hashPin('1234', 'salt');
      expect(h, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
      expect(AuthService.hashPin('1234', 'salt'), h); // same input, same hash
      expect(AuthService.hashPin('1235', 'salt'), isNot(h));
      expect(AuthService.hashPin('1234', 'other'), isNot(h));
    });

    test('only 4 digits are a valid PIN', () {
      expect(AuthService.isValidPin('0000'), isTrue);
      expect(AuthService.isValidPin('123'), isFalse);
      expect(AuthService.isValidPin('12345'), isFalse);
      expect(AuthService.isValidPin('12a4'), isFalse);
      expect(() => auth.setPin('12'), throwsArgumentError);
    });

    test('setPin stores only a hash, never the PIN', () async {
      expect(await auth.hasPin(), isFalse);
      await auth.setPin('4321');
      expect(await auth.hasPin(), isTrue);
      expect(store.data.values.any((v) => v.contains('4321')), isFalse);
    });

    test('verifyPin accepts the right PIN and rejects others', () async {
      expect(await auth.verifyPin('1111'), isFalse); // no PIN yet
      await auth.setPin('2580');
      expect(await auth.verifyPin('2580'), isTrue);
      expect(await auth.verifyPin('0852'), isFalse);
    });

    test('changing the PIN makes the old one stop working', () async {
      await auth.setPin('1111');
      await auth.setPin('2222');
      expect(await auth.verifyPin('1111'), isFalse);
      expect(await auth.verifyPin('2222'), isTrue);
    });

    test('fingerprint setting is saved', () async {
      expect(await auth.isFingerprintEnabled(), isFalse);
      await auth.setFingerprintEnabled(true);
      expect(await auth.isFingerprintEnabled(), isTrue);
    });
  });

  group('AppLockProvider.shouldRelock', () {
    final t0 = DateTime(2026, 11, 21, 10, 0, 0);

    test('less than 1 minute away → stays unlocked', () {
      expect(
        AppLockProvider.shouldRelock(t0, t0.add(const Duration(seconds: 59))),
        isFalse,
      );
    });

    test('1 minute or more away → locks', () {
      expect(
        AppLockProvider.shouldRelock(t0, t0.add(const Duration(minutes: 1))),
        isTrue,
      );
      expect(
        AppLockProvider.shouldRelock(t0, t0.add(const Duration(hours: 2))),
        isTrue,
      );
    });
  });
}
