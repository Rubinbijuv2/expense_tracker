import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Where the PIN hash lives. The real app uses [FlutterSecureStorage]
/// (encrypted by Android's Keystore); tests pass an in-memory version.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureStore implements SecureStore {
  const _FlutterSecureStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// PIN and fingerprint.
///
/// The PIN itself is never saved. We save a random "salt" and
/// SHA-256(salt + PIN). To check a PIN we hash what was typed the same way
/// and compare. The salt means two phones with PIN 1234 get different hashes.
class AuthService {
  AuthService({SecureStore? store, this._localAuth})
    : _store = store ?? const _FlutterSecureStore();

  final SecureStore _store;
  final LocalAuthentication? _localAuth;
  LocalAuthentication get _auth => _localAuth ?? LocalAuthentication();

  static const String _hashKey = 'pin_hash';
  static const String _saltKey = 'pin_salt';
  static const String _fingerprintKey = 'fingerprint_enabled';

  static const int pinLength = 4;

  /// True if [pin] is exactly 4 digits.
  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  /// SHA-256 of salt + PIN, as a 64-character hex string. Pure, so it is tested.
  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<bool> hasPin() async {
    try {
      return (await _store.read(_hashKey)) != null;
    } catch (e) {
      debugPrint('Could not read PIN: $e');
      return false;
    }
  }

  /// Saves a new PIN (first setup or "Change PIN").
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be 4 digits');
    final salt = _newSalt();
    await _store.write(_saltKey, salt);
    await _store.write(_hashKey, hashPin(pin, salt));
  }

  /// True if [pin] matches the saved PIN.
  Future<bool> verifyPin(String pin) async {
    final salt = await _store.read(_saltKey);
    final hash = await _store.read(_hashKey);
    if (salt == null || hash == null) return false;
    return hashPin(pin, salt) == hash;
  }

  // ---- Fingerprint -------------------------------------------------------

  Future<bool> isFingerprintEnabled() async =>
      (await _store.read(_fingerprintKey)) == '1';

  Future<void> setFingerprintEnabled(bool on) =>
      _store.write(_fingerprintKey, on ? '1' : '0');

  /// True if this phone has a fingerprint/face sensor with one enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('Biometrics not available: $e');
      return false;
    }
  }

  /// Shows Android's fingerprint popup. True if the finger matched.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Expense Tracker',
        biometricOnly: true,
      );
    } catch (e) {
      // Cancelled, too many tries, sensor locked, etc. → use the PIN instead.
      debugPrint('Fingerprint failed: $e');
      return false;
    }
  }
}
