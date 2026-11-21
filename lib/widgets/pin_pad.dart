import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 4 dots + a number pad. Calls [onCompleted] when 4 digits are typed,
/// then clears itself so the next try starts empty.
///
/// The parent shows mistakes through [errorText]. Give the pad a new `key`
/// when it should reset completely (e.g. moving from "Enter" to "Confirm").
/// No tooltips here: the lock screen sits above the Navigator, where
/// tooltips cannot be shown.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.errorText,
    this.enabled = true,
    this.onFingerprint,
  });

  final String title;
  final String? subtitle;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onCompleted;

  /// When set, a fingerprint button appears bottom-left.
  final VoidCallback? onFingerprint;

  static const int length = 4;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';
  bool _busy = false; // short pause after the 4th digit so its dot shows

  void _press(String d) {
    if (!widget.enabled || _busy || _digits.length >= PinPad.length) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += d);
    if (_digits.length == PinPad.length) {
      _busy = true;
      final pin = _digits;
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _digits = '';
          _busy = false;
        });
        widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (_digits.isEmpty || _busy) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: text.titleLarge, textAlign: TextAlign.center),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(widget.subtitle!,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PinPad.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _digits.length ? scheme.primary : null,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              widget.errorText ?? '',
              style: text.bodyMedium?.copyWith(color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.onFingerprint == null
                ? const SizedBox(width: 88, height: 72)
                : _iconKey(Icons.fingerprint, widget.onFingerprint!),
            _key('0'),
            _iconKey(Icons.backspace_outlined, _backspace),
          ],
        ),
      ],
    );
  }

  Widget _key(String d) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 76,
          height: 60,
          child: FilledButton.tonal(
            onPressed: widget.enabled ? () => _press(d) : null,
            child: Text(d, style: const TextStyle(fontSize: 24)),
          ),
        ),
      );

  Widget _iconKey(IconData icon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 76,
          height: 60,
          child: TextButton(
            onPressed: widget.enabled ? onTap : null,
            child: Icon(icon, size: 28),
          ),
        ),
      );
}

/// "Enter a new PIN" then "Enter it again". Calls [onPinChosen] once both
/// match. Used by onboarding and Change PIN.
class NewPinPad extends StatefulWidget {
  const NewPinPad({super.key, required this.onPinChosen});

  final ValueChanged<String> onPinChosen;

  @override
  State<NewPinPad> createState() => _NewPinPadState();
}

class _NewPinPadState extends State<NewPinPad> {
  String? _first;
  String? _error;

  void _onCompleted(String pin) {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
    } else if (pin == _first) {
      widget.onPinChosen(pin);
    } else {
      setState(() {
        _first = null;
        _error = 'PINs did not match. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return PinPad(
      key: ValueKey(confirming),
      title: confirming ? 'Enter the PIN again' : 'Choose a 4-digit PIN',
      subtitle: confirming
          ? 'To make sure you typed it right'
          : 'You will use it to open the app',
      errorText: _error,
      onCompleted: _onCompleted,
    );
  }
}
