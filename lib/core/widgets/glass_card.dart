import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Translucent card with a hairline border and optional accent glow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = AppRadii.lg,
    this.borderColor,
    this.glowColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? borderColor;
  final Color? glowColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: gradient ?? AppColors.cardGradient,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(color: glowColor!.withValues(alpha: 0.25), blurRadius: 28, spreadRadius: -6),
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: br,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded icon tile used across cards and list rows.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 44,
    this.iconSize = 22,
    this.circle = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: -4)],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
