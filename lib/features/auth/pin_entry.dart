import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pin_pad.dart';

/// Self-contained PIN entry: dots + keypad. Calls [onCompleted] when all
/// digits are entered; a non-null return is shown as an error and resets.
class PinEntryView extends StatefulWidget {
  const PinEntryView({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.header,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? header;
  final bool enabled;
  final Future<String?> Function(String pin) onCompleted;

  @override
  State<PinEntryView> createState() => PinEntryViewState();
}

class PinEntryViewState extends State<PinEntryView> {
  String _pin = '';
  String? _error;
  int _errorTick = 0;
  bool _busy = false;

  void reset() => setState(() {
        _pin = '';
        _error = null;
      });

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) {
      setState(() => _busy = true);
      final err = await widget.onCompleted(_pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        if (err != null) {
          _error = err;
          _errorTick++;
        }
      });
    }
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.header != null) ...[widget.header!, const SizedBox(height: 20)],
        Text(widget.title, style: t.headlineSmall, textAlign: TextAlign.center),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 28),
        PinDots(filled: _pin.length, errorTick: _errorTick),
        SizedBox(
          height: 36,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox.shrink()
                  : Text(
                      _error!,
                      key: ValueKey(_error! + _errorTick.toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
        PinPad(onDigit: _digit, onBackspace: _back, enabled: widget.enabled && !_busy),
      ],
    );
  }
}
