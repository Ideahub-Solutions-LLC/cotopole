import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/stats_repository.dart';
import '../events/current_event_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider);
    final stats = ref.watch(dashboardProvider).dataOrNull ?? DashboardStats.empty;
    final recent = ref.watch(recentOccurrencesProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceHigh,
      onRefresh: () async => ref.refreshData(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
              sliver: SliverList.list(
                children: [
                  _Header(name: profile?.displayName ?? ''),
                  const SizedBox(height: 18),
                  const CurrentEventCard(),
                  const SizedBox(height: 16),
                  const _QuickActions(),
                  const SectionHeader('Today at a glance'),
                  _StatsGrid(stats: stats),
                  const SectionHeader('Captures · last 7 days'),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
                    child: MiniBarChart(
                      values: stats.last7Days.map((d) => d.count).toList().ifEmpty(List.filled(7, 0)),
                      labels: stats.last7Days.isEmpty
                          ? List.generate(7, (i) => Fmt.weekday(DateTime.now().subtract(Duration(days: 6 - i))))
                          : stats.last7Days.map((d) => Fmt.weekday(d.day)).toList(),
                    ),
                  ),
                  SectionHeader(
                    'Recent captures',
                    actionLabel: 'View all',
                    onAction: () => context.go(Routes.leads),
                  ),
                  recent.when(
            skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('$e'),
                    data: (list) => list.isEmpty
                        ? const GlassCard(
                            child: EmptyState(
                              icon: Icons.contact_page_rounded,
                              title: 'No captures yet',
                              message: 'Tap the Scan button to capture your first business card.',
                            ),
                          )
                        : Column(
                            children: [
                              for (final (i, o) in list.indexed)
                                _RecentTile(occurrence: o)
                                    .animate(delay: (60 * i).ms)
                                    .fadeIn(duration: 300.ms)
                                    .slideX(begin: 0.06),
                            ],
                          ),
                  ),
                  SizedBox(height: bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _IfEmpty<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}

class _Header extends ConsumerWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CotopoleLogo(height: 30),
              const SizedBox(height: 10),
              Text(
                '${Fmt.greeting()}, ${name.split(' ').first} 👋',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(Fmt.date(DateTime.now()), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go(Routes.profile),
          child: ContactAvatar(name: name, size: 44, ring: true),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    final List<(IconData, String, Color, VoidCallback)> actions = [
      (Icons.document_scanner_rounded, 'Scan card', AppColors.primary, () => context.push(Routes.capture)),
      (Icons.edit_note_rounded, 'Type it in', AppColors.teal, () => context.push(Routes.manual)),
      if (isAdmin)
        (Icons.add_circle_outline_rounded, 'New event', AppColors.violet, () => context.push(Routes.eventNew))
      else
        (Icons.calendar_month_rounded, 'Events', AppColors.violet, () => context.go(Routes.events)),
    ];
    return Row(
      children: [
        for (final (i, a) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              onTap: a.$4,
              child: Column(
                children: [
                  IconBadge(icon: a.$1, color: a.$3, size: 44),
                  const SizedBox(height: 10),
                  Text(a.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1);
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Today', stats.capturesToday, Icons.bolt_rounded, AppColors.cyan),
      ('This week', stats.capturesThisWeek, Icons.trending_up_rounded, AppColors.primary),
      ('Hot leads', stats.hotLeads, Icons.local_fire_department_rounded, AppColors.hot),
      ('To follow up', stats.pendingFollowUps, Icons.flag_rounded, AppColors.warning),
    ];
    // Fixed tile height (not an aspect ratio) so narrow phones and larger
    // text scales don't overflow.
    final extent = 104 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: extent,
      ),
      children: [
        for (final t in tiles)
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(t.$3, color: t.$4, size: 20),
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: t.$4),
                    ),
                  ],
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: t.$2.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    v.round().toString(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
                  ),
                ),
                Text(t.$1, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentTile extends ConsumerWidget {
  const _RecentTile({required this.occurrence});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occurrence;
    final images = ref.watch(imageStoreProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push(Routes.lead(o.contactId)),
        child: Row(
          children: [
            ContactAvatar(name: o.contactName ?? '', photo: images.resolve(o.contactPhotoPath), size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.contactName ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (o.contactCompany != null) o.contactCompany!, o.eventName ?? ''].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.relative(o.capturedAt), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(methodIcon(o.captureMethod), size: 16, color: AppColors.textMuted),
                    if (o.rating != null) ...[
                      const SizedBox(width: 6),
                      Icon(ratingIcon(o.rating), size: 16, color: ratingColor(o.rating)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
