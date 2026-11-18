import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';

class _Slide {
  const _Slide(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.document_scanner_rounded,
    AppColors.primary,
    'Snap a card.\nSave a lead.',
    'Photograph a business card and Cotopole reads it on your phone — QR, vCard or printed text.',
  ),
  _Slide(
    Icons.face_retouching_natural_rounded,
    AppColors.teal,
    'Remember the face\nbehind the card',
    'Add a quick selfie and a note while the conversation is still fresh.',
  ),
  _Slide(
    Icons.shield_moon_rounded,
    AppColors.violet,
    'Works offline.\nStays on device.',
    'No signal at the venue? No problem. Everything is stored privately on this phone.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    } else {
      context.push(Routes.setup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    const CotopoleLogo(height: 30),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: () => context.push(Routes.setup),
                        child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: i == _index ? AppColors.primaryGradient : null,
                        color: i == _index ? null : AppColors.borderBright,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: GradientButton(label: last ? 'Get started' : 'Next', onPressed: _next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    // Centered when it fits; scrolls on small phones / large text.
    return Center(
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [slide.color.withValues(alpha: 0.35), slide.color.withValues(alpha: 0)],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.05, 1.05), duration: 2400.ms),
                GlassCard(
                  radius: 36,
                  padding: const EdgeInsets.all(34),
                  borderColor: slide.color.withValues(alpha: 0.5),
                  glowColor: slide.color,
                  child: Icon(slide.icon, size: 72, color: slide.color),
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.2),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.45),
          ).animate().fadeIn(delay: 220.ms),
        ],
      ),
      ),
    );
  }
}
