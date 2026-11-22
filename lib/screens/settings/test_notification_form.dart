import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/detected_sms_provider.dart';
import '../../services/notification_parser.dart';
import '../../services/sms_service.dart';
import 'sample_notification_data.dart';
import 'test_sms_screen.dart';

/// "Test notification" mode of the developer Test screen (PLAN.md 7.7):
/// pick an app, type a title and text, press Simulate → the same pipeline
/// as a real payment app notification.
class TestNotificationForm extends StatefulWidget {
  const TestNotificationForm({super.key});

  /// Not on the allow-list, to show that other apps are ignored.
  static const String otherAppPackage = 'com.whatsapp';

  @override
  State<TestNotificationForm> createState() => _TestNotificationFormState();
}

class _TestNotificationFormState extends State<TestNotificationForm> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  String _package = NotificationParser.allowedApps.keys.first;
  SmsResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _loadSample(SampleNotification? sample) {
    if (sample == null) return;
    setState(() {
      _package = sample.packageName;
      _titleCtrl.text = sample.title;
      _textCtrl.text = sample.text;
      _result = null;
    });
  }

  Future<void> _simulate() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final provider = context.read<DetectedSmsProvider>();
    SmsResult result;
    try {
      result = await provider.simulateNotification(
        _package,
        _titleCtrl.text,
        _textCtrl.text,
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<SampleNotification>(
          isExpanded: true,
          hint: const Text('Load sample'),
          decoration: const InputDecoration(
            labelText: 'Load sample',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final s in sampleNotificationList)
              DropdownMenuItem(
                value: s,
                child: Text(s.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _loadSample,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // A new key when a sample changes the app, so the field redraws.
          key: ValueKey(_package),
          initialValue: _package,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'App',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in NotificationParser.allowedApps.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
            const DropdownMenuItem(
              value: TestNotificationForm.otherAppPackage,
              child: Text('WhatsApp (not allowed, always ignored)'),
            ),
          ],
          onChanged: (v) => setState(() => _package = v ?? _package),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textCtrl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Text',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _simulate,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Simulate'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 16),
        if (_result != null) SimulateResultCard(result: _result!),
      ],
    );
  }
}
