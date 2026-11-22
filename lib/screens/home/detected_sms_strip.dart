import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/detected_sms.dart';
import '../../providers/detected_sms_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/sms_permission_dialog.dart';
import '../detected/detected_sms_screen.dart';

/// Home section for SMS detection. Shows one of:
/// - a banner "Turn on SMS detection" when permission is off (PLAN.md §6);
/// - a strip of pending detected SMS (tap to review);
/// - a small "nothing to review" card.
///
/// It also shows the permission explanation once, on the first launch.
class DetectedSmsStrip extends StatefulWidget {
  const DetectedSmsStrip({super.key});

  @override
  State<DetectedSmsStrip> createState() => _DetectedSmsStripState();
}

class _DetectedSmsStripState extends State<DetectedSmsStrip> {
  @override
  void initState() {
    super.initState();
    // Runs after the first frame is drawn, when showing a dialog is allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askOnFirstLaunch());
  }

  Future<void> _askOnFirstLaunch() async {
    final provider = context.read<DetectedSmsProvider>();
    if (await provider.shouldAskOnFirstLaunch() && mounted) {
      await askForSmsPermission(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detected = context.watch<DetectedSmsProvider>();
    final pending = detected.pending;

    if (detected.showPermissionBanner) return const _PermissionBanner();
    if (pending.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.mark_email_read_outlined),
          title: Text('Detected SMS'),
          subtitle: Text('No new payments to review.'),
        ),
      );
    }
    return _PendingStrip(pending: pending);
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sms_failed_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SMS detection is off. You can still add expenses with +.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => askForSmsPermission(context),
                child: const Text('Turn on SMS detection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingStrip extends StatelessWidget {
  const _PendingStrip({required this.pending});

  final List<DetectedSms> pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = pending.take(5).toList();
    return Card(
      color: theme.colorScheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => DetectedSmsScreen.open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(
                  pending.length == 1
                      ? '1 detected SMS'
                      : '${pending.length} detected SMS',
                ),
                subtitle: const Text('Tap to save or ignore'),
                trailing: const Icon(Icons.chevron_right),
              ),
              SizedBox(
                height: 64,
                // A sideways-scrolling row of mini cards.
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _MiniCard(sms: shown[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.sms});

  final DetectedSms sms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = sms.type == 'expense';
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${isExpense ? '−' : '+'}${formatPaise(sms.amountPaise)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isExpense
                  ? theme.colorScheme.error
                  : Colors.green.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            sms.merchant ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
