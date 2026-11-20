import 'package:flutter/material.dart';

import '../../widgets/placeholder_body.dart';

/// Date-grouped list of transactions with search and filters.
/// Placeholder for now — built in step 3.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const PlaceholderBody(
        icon: Icons.receipt_long_outlined,
        title: 'History',
        message: 'All your transactions will be listed here.',
      ),
    );
  }
}
