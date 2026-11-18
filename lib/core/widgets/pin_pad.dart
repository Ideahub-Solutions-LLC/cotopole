import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

const kPinLength = 6;

/// Row of PIN dots with a shake animation on error.
class PinDots extends StatefulWidget {
  const PinDots({super.key, required this.filled, this.length = kPinLength, this.errorTick = 0});

  final int filled;
  final int length;

  /// Increment to trigger the error shake.
  final int errorTick;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTick != oldWidget.errorTick) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final dx = math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Semantics(
        label: '${widget.filled} of ${widget.length} digits entered',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: i < widget.filled ? 16 : 14,
                height: i < widget.filled ? 16 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: i < widget.filled ? AppColors.primaryGradient : null,
                  border: Border.all(
                    color: i < widget.filled ? Colors.transparent : AppColors.borderBright,
                    width: 1.6,
                  ),
                  boxShadow: i < widget.filled
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 12)]
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Numeric keypad.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.enabled = true});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {String? sub}) => _PadKey(
          enabled: enabled,
          onTap: () => onDigit(label),
          semantic: label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(fontSize: 9, letterSpacing: 2, color: AppColors.textMuted),
                ),
            ],
          ),
        );

    const subs = ['', 'ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS', 'TUV', 'WXYZ'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var col = 1; col <= 3; col++)
                key('${row * 3 + col}', sub: subs[row * 3 + col - 1].isEmpty ? null : subs[row * 3 + col - 1]),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 78, height: 78),
            key('0'),
            _PadKey(
              enabled: enabled,
              onTap: onBackspace,
              semantic: 'Delete',
              outlined: false,
              child: const Icon(Icons.backspace_outlined, size: 26),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatefulWidget {
  const _PadKey({
    required this.child,
    required this.onTap,
    required this.semantic,
    required this.enabled,
    this.outlined = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semantic;
  final bool enabled;
  final bool outlined;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semantic,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.all(7),
          width: 78,
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _down
                ? AppColors.primary.withValues(alpha: 0.30)
                : (widget.outlined ? AppColors.surface.withValues(alpha: 0.7) : Colors.transparent),
            border: widget.outlined ? Border.all(color: AppColors.border) : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
