/// One row of the `own_accounts` table: the last 4 digits of one of the
/// user's own bank accounts or cards (used to spot self transfers).
class OwnAccount {
  final int? id;
  final String last4;
  final String? label; // e.g. "SBI savings"

  const OwnAccount({this.id, required this.last4, this.label});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'last4': last4,
    'label': label,
  };

  factory OwnAccount.fromMap(Map<String, Object?> map) => OwnAccount(
    id: map['id'] as int?,
    last4: map['last4'] as String,
    label: map['label'] as String?,
  );
}
