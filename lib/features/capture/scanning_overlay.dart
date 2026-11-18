import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen "reading the card" moment: the photo inside a glowing frame
/// with a sweeping scan line and corner brackets.
class ScanningOverlay extends StatelessWidget {
  const ScanningOverlay({super.key, required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Reading the business card',
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: AppColors.background.withValues(alpha: 0.75),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 40),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(File(imagePath), fit: BoxFit.cover, cacheWidth: 900),
                          ),
                        ),
                        const _Corners(),
                        LayoutBuilder(
                          builder: (context, c) => Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: const LinearGradient(
                                  colors: [Colors.transparent, AppColors.cyan, Colors.transparent],
                                ),
                                boxShadow: [
                                  BoxShadow(color: AppColors.cyan.withValues(alpha: 0.9), blurRadius: 16, spreadRadius: 2),
                                ],
                              ),
                            )
                                .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                                .moveY(begin: 4, end: c.maxHeight - 8, duration: 1100.ms, curve: Curves.easeInOut),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack, duration: 400.ms),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.violet, size: 20)
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 2.seconds),
                      const SizedBox(width: 10),
                      Text('Reading the card…', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'QR / vCard first, then on-device text recognition',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CornersPainter()));
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 26.0;
    const o = -6.0;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(o, o + l)
      ..lineTo(o, o)
      ..lineTo(o + l, o)
      ..moveTo(w - o - l, o)
      ..lineTo(w - o, o)
      ..lineTo(w - o, o + l)
      ..moveTo(w - o, h - o - l)
      ..lineTo(w - o, h - o)
      ..lineTo(w - o - l, h - o)
      ..moveTo(o + l, h - o)
      ..lineTo(o, h - o)
      ..lineTo(o, h - o - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
