import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Deep-navy canvas with soft blue/violet glows and a faint tech grid,
/// echoing the concept design's holographic look without heavy blur.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundAlt, AppColors.background],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            left: -100,
            child: _Glow(color: AppColors.primary.withValues(alpha: 0.28 * intensity), size: 380),
          ),
          Positioned(
            top: 220,
            right: -160,
            child: _Glow(color: AppColors.violet.withValues(alpha: 0.18 * intensity), size: 360),
          ),
          Positioned(
            bottom: -180,
            left: -60,
            child: _Glow(color: AppColors.cyan.withValues(alpha: 0.10 * intensity), size: 360),
          ),
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.45), paint);
    }
    for (double y = 0; y < size.height * 0.45; y += step) {
      final fade = 1 - (y / (size.height * 0.45));
      paint.color = Colors.white.withValues(alpha: 0.03 * fade);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
