import 'package:flutter/material.dart';

import '../../widgets/placeholder_body.dart';
import '../add_edit/add_edit_screen.dart';

/// Dashboard: budget card, pie chart, detected SMS, recent transactions.
/// Placeholder for now — built in step 4. The + button already works.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_home', // must differ from History's + button
        tooltip: 'Add transaction',
        onPressed: () => AddEditScreen.open(context),
        child: const Icon(Icons.add),
      ),
      body: const PlaceholderBody(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Home',
        message: 'Your monthly summary will appear here.',
      ),
    );
  }
}
