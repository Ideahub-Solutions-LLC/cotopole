import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';

/// Tab scaffold with the concept design's floating glass bar and the raised
/// glowing Scan button in the centre (the app's primary action).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AppBackground(child: navigationShell),
      bottomNavigationBar: _BottomBar(
        index: navigationShell.currentIndex,
        onTap: _go,
        onScan: () {
          HapticFeedback.mediumImpact();
          context.push(Routes.capture);
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap, required this.onScan});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 110 + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: bottom > 0 ? bottom - 6 : 10,
            height: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _NavItem(icon: Icons.home_rounded, label: 'Home', selected: index == 0, onTap: () => onTap(0)),
                      _NavItem(icon: Icons.people_alt_rounded, label: 'Leads', selected: index == 1, onTap: () => onTap(1)),
                      const SizedBox(width: 84),
                      _NavItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Events',
                        selected: index == 2,
                        onTap: () => onTap(2),
                      ),
                      _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: index == 3, onTap: () => onTap(3)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: (bottom > 0 ? bottom - 6 : 10) + 14,
            child: _ScanButton(onTap: onScan),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                ),
                child: Icon(icon, size: 24, color: selected ? AppColors.primary : color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan a business card',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2F6BFF), Color(0xFF7C4DFF)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35 + 0.25 * _pulse.value),
                      blurRadius: 18 + 14 * _pulse.value,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scan',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
