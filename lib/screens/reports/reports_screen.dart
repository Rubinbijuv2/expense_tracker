import 'package:flutter/material.dart';

import '../../widgets/placeholder_body.dart';

/// Charts, top merchants and CSV/PDF export.
/// Placeholder for now — built in step 9.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const PlaceholderBody(
        icon: Icons.bar_chart_outlined,
        title: 'Reports',
        message: 'Charts and exports will appear here.',
      ),
    );
  }
}
