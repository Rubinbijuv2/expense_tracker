import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// One chip per payment mode (Cash, UPI, Card, Net banking); one is selected.
class PaymentModeChips extends StatelessWidget {
  const PaymentModeChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final mode in AppConstants.paymentModes)
          ChoiceChip(
            label: Text(mode),
            selected: selected == mode,
            onSelected: (_) => onSelected(mode),
          ),
      ],
    );
  }
}
