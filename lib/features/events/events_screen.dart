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
import '../../data/repositories/event_repository.dart';
import 'event_picker_sheet.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  EventFilter _filter = EventFilter.active;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    // Staff see active events only (SOP-004 §5.1).
    final filter = isAdmin ? _filter : EventFilter.active;
    final events = ref.watch(eventsProvider((filter: filter, query: _query)));
    final current = ref.watch(currentEventProvider).dataOrNull;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text('Events', style: Theme.of(context).textTheme.headlineMedium)),
                if (isAdmin)
                  FilledButton.icon(
                    onPressed: () => context.push(Routes.eventNew),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('New'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search events or venues',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<EventFilter>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.22),
                    selectedForegroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  segments: const [
                    ButtonSegment(value: EventFilter.active, label: Text('Active')),
                    ButtonSegment(value: EventFilter.archived, label: Text('Archived')),
                    ButtonSegment(value: EventFilter.all, label: Text('All')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refreshData(),
              child: events.when(
            skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) => list.isEmpty
                    ? ListView(
                        children: [
                          EmptyState(
                            icon: Icons.event_note_rounded,
                            title: _query.isEmpty ? 'No events here' : 'No matching events',
                            message: isAdmin
                                ? 'Create the event before doors open so staff can pick it on the floor.'
                                : 'Your organiser has not created an active event yet.',
                            action: isAdmin
                                ? FilledButton.icon(
                                    onPressed: () => context.push(Routes.eventNew),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Create event'),
                                  )
                                : null,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, bottom + 24),
                        itemCount: list.length,
                        itemBuilder: (context, i) => EventCard(
                          event: list[i],
                          isCurrent: list[i].id == current?.id,
                        ).animate(delay: (i < 10 ? i * 45 : 0).ms).fadeIn(duration: 280.ms).slideY(begin: 0.1),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.isCurrent = false});
  final Event event;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final (statusLabel, statusColor) = e.isArchived
        ? ('Archived', AppColors.textMuted)
        : e.isLive
            ? ('Live today', AppColors.success)
            : e.isUpcoming
                ? ('Upcoming', AppColors.cyan)
                : ('Past', AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: isCurrent ? AppColors.primary.withValues(alpha: 0.7) : null,
        glowColor: isCurrent ? AppColors.primary : null,
        onTap: () => context.push(Routes.event(e.id)),
        onLongPress: e.isArchived
            ? null
            : () async {
                await setCurrentEvent(ref, e.id);
                if (context.mounted) showAppSnack(context, 'Capturing at ${e.name}', icon: Icons.event_available_rounded);
              },
        child: Row(
          children: [
            DateBlock(date: e.startsAt),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(Fmt.time(e.startsAt), style: Theme.of(context).textTheme.bodySmall),
                      if (e.location != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.place_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            e.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: statusLabel,
                        color: statusColor,
                        icon: e.isLive ? Icons.circle : null,
                        dense: true,
                      ),
                      StatusPill(
                        label: '${e.contactCount} captured',
                        color: AppColors.primary,
                        icon: Icons.people_alt_rounded,
                        dense: true,
                      ),
                      if (isCurrent)
                        const StatusPill(
                          label: 'Capturing here',
                          color: AppColors.violet,
                          icon: Icons.radio_button_checked_rounded,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
