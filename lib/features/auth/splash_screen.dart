import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final started = DateTime.now();
    final count = await ref.read(profileRepoProvider).count();
    // Let the brand moment breathe without making people wait.
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 1100);
    if (elapsed < minShow) await Future<void>.delayed(minShow - elapsed);
    if (!mounted) return;
    context.go(count == 0 ? Routes.welcome : Routes.unlock);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        intensity: 1.3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CotopoleLogo(height: 64)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack, duration: 700.ms),
              const SizedBox(height: 14),
              const Text(
                'CONNECTING TO PEOPLE',
                style: TextStyle(
                  letterSpacing: 4,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideY(begin: 0.4),
              const SizedBox(height: 48),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.primary,
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
