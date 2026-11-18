import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';

/// Sets the event that new captures are attributed to.
Future<void> setCurrentEvent(WidgetRef ref, String eventId) async {
  await ref.read(settingsRepoProvider).set(SettingsRepository.kCurrentEventId, eventId);
  ref.refreshData();
}

/// Bottom sheet listing active events. Staff see active events only; the
/// organiser can also jump to creating one.
Future<Event?> showEventPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Event>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => const _EventPickerSheet(),
  ).then((picked) async {
    if (picked != null) await setCurrentEvent(ref, picked.id);
    return picked;
  });
}

class _EventPickerSheet extends ConsumerWidget {
  const _EventPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(activeEventsProvider);
    final current = ref.watch(currentEventProvider).dataOrNull;
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text('Choose event', style: Theme.of(context).textTheme.titleLarge)),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(Routes.eventNew);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: events.when(
            skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No active events',
                      message: isAdmin
                          ? 'Create the event before doors open.'
                          : 'Ask your organiser to create the event first.',
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final e = list[i];
                        final selected = e.id == current?.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: selected ? AppColors.primary.withValues(alpha: 0.14) : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                              ),
                              leading: _DateBlock(date: e.startsAt),
                              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                [
                                  if (e.location != null) e.location!,
                                  '${e.contactCount} captured',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                  : (e.isLive ? const LiveDot() : null),
                              onTap: () => Navigator.pop(context, e),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.35), AppColors.violet.withValues(alpha: 0.2)],
        ),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.dateShort(date).split(' ').first.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.cyan),
          ),
          Text('${date.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Public so other screens can reuse the calendar tile.
class DateBlock extends _DateBlock {
  const DateBlock({required super.date});
}
