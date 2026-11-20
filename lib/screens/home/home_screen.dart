import 'package:flutter/material.dart';

import '../../widgets/placeholder_body.dart';

/// Dashboard: budget card, pie chart, detected SMS, recent transactions.
/// Placeholder for now — built in step 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const PlaceholderBody(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Home',
        message: 'Your monthly summary will appear here.',
      ),
    );
  }
}
