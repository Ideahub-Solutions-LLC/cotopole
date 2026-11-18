import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import 'event_picker_sheet.dart';

/// The concept design's event hero: calendar orb, EVENT eyebrow, name,
/// date pill and a "Change Event" gradient pill.
class CurrentEventCard extends ConsumerWidget {
  const CurrentEventCard({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(currentEventProvider);
    final event = eventAsync.dataOrNull;

    return GlassCard(
      padding: EdgeInsets.fromLTRB(20, compact ? 18 : 22, 20, compact ? 18 : 22),
      radius: AppRadii.xl,
      glowColor: AppColors.primary,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF13205A).withValues(alpha: 0.9),
          const Color(0xFF0B1235).withValues(alpha: 0.9),
        ],
      ),
      onTap: event == null ? null : () => context.push(Routes.event(event.id)),
      child: Stack(
        children: [
          Positioned(right: -10, top: -10, child: _Waves(size: compact ? 110 : 150)),
          Column(
            children: [
              if (!compact) ...[
                const IconBadge(icon: Icons.event_rounded, circle: true, size: 56, iconSize: 26),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (event?.isLive ?? false) ...[const LiveDot(), const SizedBox(width: 6)],
                  Text(
                    event == null ? 'NO EVENT SELECTED' : (event.isLive ? 'LIVE EVENT' : 'EVENT'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      letterSpacing: 2.4,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event?.name ?? 'Pick where you are',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: compact ? 22 : 26),
              ),
              const SizedBox(height: 10),
              if (event != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(icon: Icons.calendar_today_rounded, label: Fmt.date(event.startsAt)),
                    if (event.location != null) _Pill(icon: Icons.place_rounded, label: event.location!),
                    _Pill(icon: Icons.people_alt_rounded, label: '${event.contactCount} captured'),
                  ],
                )
              else
                Text(
                  'Every capture is recorded against an event.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              SizedBox(height: compact ? 14 : 18),
              GradientButton(
                label: event == null ? 'Choose Event' : 'Change Event',
                expand: false,
                height: 48,
                onPressed: () => showEventPicker(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative concentric arcs (the concept's holographic wave lines).
class _Waves extends StatelessWidget {
  const _Waves({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(size: Size.square(size), painter: _WavesPainter()));
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      p.color = AppColors.primary.withValues(alpha: 0.18 - i * 0.025);
      canvas.drawCircle(Offset(size.width, 0), size.width * (0.35 + i * 0.13), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
