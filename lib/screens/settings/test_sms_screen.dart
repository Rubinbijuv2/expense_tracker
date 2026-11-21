import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/detected_sms_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../detected/detected_sms_screen.dart';
import 'sample_sms_data.dart';

/// Developer screen: type (or load) an SMS and push it through the real
/// detection pipeline, as if it had just arrived on the phone.
///
/// Opened by tapping the version number in Settings 5 times, and always
/// listed in debug builds.
class TestSmsScreen extends StatefulWidget {
  const TestSmsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TestSmsScreen()));

  @override
  State<TestSmsScreen> createState() => _TestSmsScreenState();
}

class _TestSmsScreenState extends State<TestSmsScreen> {
  final _senderCtrl = TextEditingController(text: 'AX-HDFCBK');
  final _bodyCtrl = TextEditingController();
  SmsResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _senderCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _loadSample(SampleSms? sample) {
    if (sample == null) return;
    setState(() {
      _senderCtrl.text = sample.sender;
      _bodyCtrl.text = sample.body;
      _result = null;
    });
  }

  Future<void> _simulate() async {
    FocusScope.of(context).unfocus(); // hide the keyboard
    setState(() => _busy = true);
    final provider = context.read<DetectedSmsProvider>();
    SmsResult result;
    try {
      result = await provider.simulateIncoming(
          _senderCtrl.text.trim(), _bodyCtrl.text);
    } catch (e) {
      result = SmsResult.ignored('error: $e');
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Test SMS (developer)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sends the text through the same steps as a real incoming SMS: '
            'filter, parse, category guess, duplicate check, save as pending '
            'and notification.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SampleSms>(
            isExpanded: true,
            hint: const Text('Load sample'),
            decoration: const InputDecoration(
              labelText: 'Load sample',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in sampleSmsList)
                DropdownMenuItem(
                  value: s,
                  child: Text(s.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _loadSample,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _senderCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Sender',
              helperText: 'Bank senders look like AX-HDFCBK',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _simulate,
            icon: const Icon(Icons.sms),
            label: const Text('Simulate incoming SMS'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 16),
          if (_result != null) _ResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final SmsResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final saved = result.saved;

    if (saved == null) {
      return Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: const Icon(Icons.block),
          title: Text('Ignored: ${result.ignoredReason}'),
        ),
      );
    }

    final category = saved.guessedCategoryId == null
        ? null
        : context.read<TransactionProvider>().categoryById(saved.guessedCategoryId!);
    final text = 'Detected: ${NotificationService.shortAmount(saved.amountPaise)}, '
        '${saved.merchant ?? 'Unknown'}, ${category?.name ?? 'no category'}';

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(text),
            subtitle: Text('${saved.type} · ${saved.paymentMode ?? 'mode ?'}'
                '${saved.accountLast4 == null ? '' : ' · A/c ••${saved.accountLast4}'}'
                ' · saved as pending'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => DetectedSmsScreen.open(context),
              child: const Text('Open Detected SMS'),
            ),
          ),
        ],
      ),
    );
  }
}
