import 'package:flutter/foundation.dart';

import '../data/own_account_repo.dart';
import '../models/own_account.dart';

/// Settings → My accounts: the last 4 digits of the user's own accounts,
/// used to spot self transfers (PLAN.md rule 13).
class OwnAccountsProvider extends ChangeNotifier {
  OwnAccountsProvider({OwnAccountRepo? repo})
    : _repo = repo ?? OwnAccountRepo();

  final OwnAccountRepo _repo;
  List<OwnAccount> _accounts = [];

  List<OwnAccount> get accounts => List.unmodifiable(_accounts);

  Future<void> load() async {
    try {
      _accounts = await _repo.getAll();
    } catch (e) {
      debugPrint('Could not load own accounts: $e');
    }
    notifyListeners();
  }

  bool has(String last4) => _accounts.any((a) => a.last4 == last4.trim());

  /// Returns false if these 4 digits were already saved.
  Future<bool> add(String last4, String? label) async {
    final digits = last4.trim();
    if (has(digits)) return false;
    final name = label?.trim() ?? '';
    await _repo.insert(
      OwnAccount(last4: digits, label: name.isEmpty ? null : name),
    );
    await load();
    return true;
  }

  Future<void> remove(OwnAccount account) async {
    await _repo.delete(account.id!);
    await load();
  }
}
