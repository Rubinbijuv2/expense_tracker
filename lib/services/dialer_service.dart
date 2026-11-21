import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens the phone's dialer with a number filled in. The user still presses
/// the call button, so the app needs no CALL_PHONE permission.
///
/// A MethodChannel is a named pipe between Dart and the Android (Kotlin)
/// side; MainActivity.kt answers the "dial" call. No extra package needed.
class DialerService {
  DialerService._();

  static const MethodChannel _channel = MethodChannel('expense_tracker/dialer');

  /// Returns false if the number is empty or no dialer app could open.
  static Future<bool> dial(String? phone) async {
    final number = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('dial', {'phone': number}) ??
          false;
    } catch (e) {
      debugPrint('Could not open dialer: $e');
      return false;
    }
  }
}
