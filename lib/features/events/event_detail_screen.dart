import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/services/export_service.dart';
import 'event_picker_sheet.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: eventAsync.when(
            skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (e) => e == null
              ? const Center(
                  child: EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Event not found',
                    message: 'It may have been removed.',
                  ),
                )
              : _Body(event: e),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});
  final Event event;

  Future<void> _export(BuildContext context, WidgetRef ref, List<Occurrence> occ) async {
    if (occ.isEmpty) {
      showAppSnack(context, 'Nothing to export yet', icon: Icons.info_rounded, color: AppColors.cyan);
      return;
    }
    final repo = ref.read(contactRepoProvider);
    final contacts = <String, Contact>{};
    for (final o in occ) {
      contacts[o.contactId] ??= (await repo.get(o.contactId))!;
    }
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await ref.read(exportServiceProvider).shareText(
          '${ExportService.safeFileName(event.name)}_leads.csv',
          ExportService.occurrencesCsv(occ, contacts),
          mime: 'text/csv',
          subject: '${event.name} — leads',
          origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref) async {
    final archiving = !event.isArchived;
    final ok = await confirmDialog(
      context,
      title: archiving ? 'Archive event?' : 'Restore event?',
      message: archiving
          ? 'Archiving stops further captures. Existing meetings stay readable, and staff stop seeing it in their list.'
          : 'The event becomes active again and accepts captures.',
      confirmLabel: archiving ? 'Archive' : 'Restore',
    );
    if (!ok) return;
    try {
      await ref.read(eventRepoProvider).setArchived(event, archiving, actorId: ref.read(sessionProvider)?.id);
      ref.refreshData();
      if (context.mounted) showAppSnack(context, archiving ? 'Event archived' : 'Event restored');
    } on EventConflictException catch (e) {
      if (context.mounted) showAppSnack(context, e.toString(), icon: Icons.error_rounded, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    final stats = ref.watch(eventStatsProvider(e.id)).dataOrNull;
    final occurrences = ref.watch(eventOccurrencesProvider(e.id));
    final current = ref.watch(currentEventProvider).dataOrNull;
    final isCurrent = current?.id == e.id;
    final images = ref.watch(imageStoreProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Export leads (CSV)',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _export(context, ref, occurrences.dataOrNull ?? const []),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) {
                  if (v == 'edit') context.push(Routes.eventEdit(e.id));
                  if (v == 'archive') _toggleArchive(context, ref);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit event')),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: ListTile(
                      leading: Icon(e.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
                      title: Text(e.isArchived ? 'Restore event' : 'Archive event'),
                    ),
                  ),
                ],
              ),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, bottom + 32),
          sliver: SliverList.list(
            children: [
              _Hero(event: e, isCurrent: isCurrent),
              const SizedBox(height: 14),
              if (!e.isArchived)
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        label: isCurrent ? 'Capture lead' : 'Capture here',
                        icon: Icons.qr_code_scanner_rounded,
                        showArrow: false,
                        height: 52,
                        onPressed: () async {
                          if (!isCurrent) await setCurrentEvent(ref, e.id);
                          if (context.mounted) context.push(Routes.capture);
                        },
                      ),
                    ),
                  ],
                ),
              const SectionHeader('Event results'),
              _StatsRow(stats: stats),
              if (stats != null && stats.total > 0) ...[
                const SizedBox(height: 12),
                _MethodBreakdown(stats: stats),
              ],
              SectionHeader('Captured leads · ${stats?.total ?? 0}'),
              occurrences.when(
            skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('$err'),
                data: (list) => list.isEmpty
                    ? GlassCard(
                        child: EmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'No captures yet',
                          message: e.isArchived
                              ? 'This event is archived.'
                              : 'Leads captured at this event will appear here.',
                        ),
                      )
                    : Column(
                        children: [
                          for (final (i, o) in list.indexed)
                            _OccurrenceTile(occurrence: o, photo: images.resolve(o.contactPhotoPath))
                                .animate(delay: (i < 12 ? i * 40 : 0).ms)
                                .fadeIn(duration: 260.ms),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.event, required this.isCurrent});
  final Event event;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return GlassCard(
      radius: AppRadii.xl,
      glowColor: AppColors.violet,
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1B2470).withValues(alpha: 0.95),
          const Color(0xFF2A1659).withValues(alpha: 0.9),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (e.isLive) ...[const LiveDot(), const SizedBox(width: 6)],
              Text(
                e.isArchived ? 'ARCHIVED' : (e.isLive ? 'LIVE TODAY' : (e.isUpcoming ? 'UPCOMING' : 'EVENT')),
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: e.isArchived ? AppColors.textMuted : AppColors.cyan,
                ),
              ),
              const Spacer(),
              if (isCurrent)
                const StatusPill(label: 'Current', color: AppColors.success, icon: Icons.check_rounded, dense: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(e.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _line(context, Icons.calendar_today_rounded, Fmt.dateTime(e.startsAt)),
          if (e.location != null) _line(context, Icons.place_rounded, e.location!),
          if (e.notes != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(e.notes!, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final EventStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final items = [
      ('Captured', s?.total ?? 0, AppColors.primary),
      ('New', s?.newContacts ?? 0, AppColors.success),
      ('Returning', s?.returning ?? 0, AppColors.cyan),
      ('Hot', s?.hot ?? 0, AppColors.hot),
    ];
    return Row(
      children: [
        for (final (i, it) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                children: [
                  Text(
                    '${it.$2}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: it.$3),
                  ),
                  const SizedBox(height: 2),
                  Text(it.$1, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodBreakdown extends StatelessWidget {
  const _MethodBreakdown({required this.stats});
  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    const colors = {
      CaptureMethod.image: AppColors.primary,
      CaptureMethod.qr: AppColors.success,
      CaptureMethod.mixed: AppColors.violet,
      CaptureMethod.manual: AppColors.teal,
    };
    final total = stats.total == 0 ? 1 : stats.total;
    final followRate = (stats.followedUp / total * 100).round();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How leads were captured', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final m in CaptureMethod.values)
                    if ((stats.byMethod[m] ?? 0) > 0)
                      Expanded(
                        flex: stats.byMethod[m]!,
                        child: Container(color: colors[m]),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final m in CaptureMethod.values)
                if ((stats.byMethod[m] ?? 0) > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors[m], borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 6),
                      Text('${m.label} · ${stats.byMethod[m]}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Follow-up progress',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text('$followRate%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.followedUp / total,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence, required this.photo});
  final Occurrence occurrence;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push(Routes.lead(o.contactId)),
        child: Row(
          children: [
            ContactAvatar(name: o.contactName ?? '', photo: photo, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.contactName ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    (o.notes ?? '').isNotEmpty ? o.notes! : (o.contactCompany ?? o.duplicateResolution.label),
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
                Text(Fmt.time(o.capturedAt), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(methodIcon(o.captureMethod), size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: followUpColor(o.followUpStatus),
                      ),
                    ),
                    if (o.rating != null) ...[
                      const SizedBox(width: 4),
                      Icon(ratingIcon(o.rating), size: 15, color: ratingColor(o.rating)),
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
