import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/models.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class CotopoleLogo extends StatelessWidget {
  const CotopoleLogo({super.key, this.height = 34});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cotopole',
      image: true,
      child: Image.asset(
        'assets/images/cotople_logo.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, AppSpacing.xl, 4, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" dot used on today's events.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.success});
  final Color color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 6 + 8 * _c.value,
              height: 6 + 8 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.5 * (1 - _c.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.primary.withValues(alpha: 0.30), AppColors.primary.withValues(alpha: 0.02)],
              ),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Circular avatar showing the client selfie when available, otherwise
/// gradient initials.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 48,
    this.ring = false,
  });

  final String name;
  final File? photo;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = Fmt.initials(parts.isNotEmpty ? parts.first : '', parts.length > 1 ? parts.last : '');
    final inner = photo != null
        ? ClipOval(
            child: Image.file(
              photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => _initials(initials),
            ),
          )
        : _initials(initials);
    if (!ring) return SizedBox(width: size, height: size, child: inner);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
        child: SizedBox(width: size, height: size, child: inner),
      ),
    );
  }

  Widget _initials(String initials) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.avatarGradient(name)),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
            letterSpacing: 0.5,
          ),
        ),
      );
}

Color ratingColor(LeadRating? r) => switch (r) {
      LeadRating.hot => AppColors.hot,
      LeadRating.warm => AppColors.warning,
      LeadRating.cold => AppColors.cyan,
      null => AppColors.textMuted,
    };

IconData ratingIcon(LeadRating? r) => switch (r) {
      LeadRating.hot => Icons.local_fire_department_rounded,
      LeadRating.warm => Icons.wb_sunny_rounded,
      LeadRating.cold => Icons.ac_unit_rounded,
      null => Icons.remove_rounded,
    };

IconData methodIcon(CaptureMethod m) => switch (m) {
      CaptureMethod.manual => Icons.edit_note_rounded,
      CaptureMethod.image => Icons.document_scanner_rounded,
      CaptureMethod.qr => Icons.qr_code_2_rounded,
      CaptureMethod.mixed => Icons.auto_awesome_rounded,
    };

Color resolutionColor(DuplicateResolution r) => switch (r) {
      DuplicateResolution.newContact => AppColors.success,
      DuplicateResolution.phoneMatch => AppColors.cyan,
      DuplicateResolution.emailMatch => AppColors.cyan,
      DuplicateResolution.adminResolved => AppColors.violet,
    };

Color followUpColor(FollowUpStatus s) => switch (s) {
      FollowUpStatus.pending => AppColors.warning,
      FollowUpStatus.contacted => AppColors.primary,
      FollowUpStatus.done => AppColors.success,
    };

/// Segmented Hot / Warm / Cold selector.
class RatingSelector extends StatelessWidget {
  const RatingSelector({super.key, required this.value, required this.onChanged});

  final LeadRating? value;
  final ValueChanged<LeadRating?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in LeadRating.values) ...[
          Expanded(
            child: _RatingChip(
              rating: r,
              selected: value == r,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(value == r ? null : r);
              },
            ),
          ),
          if (r != LeadRating.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.selected, required this.onTap});
  final LeadRating rating;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ratingColor(rating);
    return Semantics(
      button: true,
      selected: selected,
      label: '${rating.label} lead',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: selected ? c.withValues(alpha: 0.22) : AppColors.surface.withValues(alpha: 0.7),
            border: Border.all(color: selected ? c : AppColors.border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ratingIcon(rating), size: 18, color: selected ? c : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                rating.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? c : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seven-day capture bars for the dashboard.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.values, required this.labels, this.height = 110});

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] == 0 ? '' : '${values[i]}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  // The bar takes whatever height the labels leave, so the
                  // column never overflows (incl. at larger text scales).
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maxV == 0 ? 0.04 : (values[i] / maxV).clamp(0.04, 1.0)),
                    duration: Duration(milliseconds: 500 + i * 70),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => FractionallySizedBox(
                      heightFactor: t,
                      child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: i == values.length - 1
                            ? const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFF2F6BFF), Color(0xFF22D3EE)],
                              )
                            : LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.35),
                                  AppColors.violet.withValues(alpha: 0.55),
                                ],
                              ),
                      ),
                    ),
                    ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == values.length - 1 ? FontWeight.w800 : FontWeight.w600,
                      color: i == values.length - 1 ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen, zoomable image viewer.
class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({super.key, required this.file, required this.title});
  final File file;
  final String title;

  static Future<void> open(BuildContext context, File file, String title) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => PhotoViewerPage(file: file, title: title),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: file.path,
          child: InteractiveViewer(maxScale: 5, child: Image.file(file)),
        ),
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {IconData? icon, Color? color}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? Icons.check_circle_rounded, color: color ?? AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.danger : AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}
