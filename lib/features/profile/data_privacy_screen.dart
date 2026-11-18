import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/export_service.dart';

class DataPrivacyScreen extends ConsumerWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageStatsProvider).dataOrNull;
    final retention = ref.watch(retentionDaysProvider).dataOrNull ?? SettingsRepository.defaultRetentionDays;
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Data & privacy')),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 28),
            children: [
              GlassCard(
                glowColor: AppColors.teal,
                child: Row(
                  children: [
                    const IconBadge(icon: Icons.phonelink_lock_rounded, color: AppColors.teal, size: 50),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Cotopole stores everything in a local SQLite database inside this app. '
                        'There is no cloud database and nothing is uploaded.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader('On this device'),
              GlassCard(
                child: storage == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          _kv(context, 'Leads', '${storage.$1.contacts}'),
                          _kv(context, 'Meetings recorded', '${storage.$1.occurrences}'),
                          _kv(context, 'Events', '${storage.$1.events}'),
                          _kv(context, 'Team members', '${storage.$1.profiles}'),
                          _kv(context, 'Photos', Fmt.bytes(storage.$2)),
                          _kv(context, 'Audit log entries', '${storage.$1.auditEvents}'),
                        ],
                      ),
              ),
              const SectionHeader('Photo retention'),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card photos and client selfies are deleted automatically after this period. '
                      'Lead details and notes are kept.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in const [30, 90, 365, 0])
                          ChoiceChip(
                            label: Text(d == 0 ? 'Keep' : '$d days'),
                            selected: retention == d,
                            showCheckmark: false,
                            onSelected: isAdmin
                                ? (_) async {
                                    await ref.read(settingsRepoProvider).set(SettingsRepository.kRetentionDays, '$d');
                                    final removed = await ref.read(retentionServiceProvider).purge(days: d);
                                    ref.refreshData();
                                    if (context.mounted && removed > 0) {
                                      showAppSnack(context, '$removed old photo${removed == 1 ? '' : 's'} removed');
                                    }
                                  }
                                : null,
                          ),
                      ],
                    ),
                    if (!isAdmin) ...[
                      const SizedBox(height: 8),
                      Text('Only an organiser can change this.', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SectionHeader('Export'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const IconBadge(icon: Icons.table_view_rounded, size: 38, iconSize: 19),
                  title: const Text('Export all meetings (CSV)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Hand leads to your CRM or follow-up tool'),
                  trailing: const Icon(Icons.ios_share_rounded),
                  onTap: () => _exportAll(context, ref),
                ),
              ),
              if (isAdmin) ...[
                const SectionHeader('Danger zone'),
                GlassCard(
                  borderColor: AppColors.danger.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const IconBadge(
                      icon: Icons.delete_forever_rounded,
                      color: AppColors.danger,
                      size: 38,
                      iconSize: 19,
                    ),
                    title: const Text(
                      'Erase all leads & photos',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                    ),
                    subtitle: const Text('Events and team members are kept'),
                    onTap: () => _eraseAll(context, ref),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Theme.of(context).textTheme.bodyMedium)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(contactRepoProvider);
    final occ = await repo.allOccurrences();
    if (occ.isEmpty) {
      if (context.mounted) {
        showAppSnack(context, 'Nothing to export yet', icon: Icons.info_rounded, color: AppColors.cyan);
      }
      return;
    }
    final contacts = {for (final c in await repo.list()) c.id: c};
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    await ref.read(exportServiceProvider).shareText(
          'cotopole_leads_$stamp.csv',
          ExportService.occurrencesCsv(occ, contacts),
          mime: 'text/csv',
          subject: 'Cotopole leads export',
          origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
  }

  Future<void> _eraseAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Erase all leads?',
      message: 'Every lead, meeting record and photo on this device will be permanently deleted. '
          'This cannot be undone. Export first if you need a copy.',
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(contactRepoProvider);
    final actor = ref.read(sessionProvider)?.id;
    final all = await repo.list();
    for (final Contact c in all) {
      await repo.delete(c.id, actorId: actor);
    }
    await ref.read(imageStoreProvider).deleteAll();
    ref.refreshData();
    if (context.mounted) showAppSnack(context, 'All leads erased', icon: Icons.delete_rounded);
  }
}
