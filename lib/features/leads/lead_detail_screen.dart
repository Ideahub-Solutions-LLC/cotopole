import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart';
import '../../data/services/export_service.dart';
import '../../data/services/image_store.dart';
import '../capture/photo_slot.dart';

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactProvider(contactId));
    final images = ref.watch(imageStoreProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: contactAsync.when(
            skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (c) => c == null
              ? Center(
                  child: EmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'Lead not found',
                    message: 'It may have been deleted.',
                    action: TextButton(onPressed: () => context.pop(), child: const Text('Go back')),
                  ),
                )
              : _Body(contact: c, images: images),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.contact, required this.images});
  final Contact contact;
  final ImageStore images;

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnack(context, 'No app available to open this', icon: Icons.error_rounded, color: AppColors.danger);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'No app available to open this', icon: Icons.error_rounded, color: AppColors.danger);
      }
    }
  }

  Uri _web(String url) => Uri.parse(url.startsWith('http') ? url : 'https://$url');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contact;
    final occurrences = ref.watch(contactOccurrencesProvider(c.id));
    final photo = images.resolve(c.photoPath);
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
              tooltip: c.isFavorite ? 'Remove from favourites' : 'Add to favourites',
              icon: Icon(
                c.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: c.isFavorite ? AppColors.brandAmber : null,
              ),
              onPressed: () async {
                HapticFeedback.selectionClick();
                await ref.read(contactRepoProvider).setFavorite(c.id, !c.isFavorite);
                ref.refreshData();
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => _menu(context, ref, v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit details')),
                ),
                PopupMenuItem(
                  value: 'photo',
                  child: ListTile(leading: Icon(Icons.add_a_photo_rounded), title: Text('Change photo')),
                ),
                PopupMenuItem(
                  value: 'vcard',
                  child: ListTile(leading: Icon(Icons.contact_page_rounded), title: Text('Share as contact card')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                    title: Text('Erase lead', style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 32),
          sliver: SliverList.list(
            children: [
              Center(
                child: GestureDetector(
                  onTap: photo == null ? null : () => PhotoViewerPage.open(context, photo, c.fullName),
                  child: Hero(
                    tag: 'avatar-${c.id}',
                    child: ContactAvatar(name: c.fullName, photo: photo, size: 104, ring: true),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(c.fullName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              if (c.subtitle.isNotEmpty && (c.position != null || c.company != null)) ...[
                const SizedBox(height: 4),
                Text(
                  [c.position, c.company].whereType<String>().join(' at '),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  _Action(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    color: AppColors.success,
                    onTap: c.phone == null ? null : () => _launch(context, Uri(scheme: 'tel', path: c.phone)),
                  ),
                  _Action(
                    icon: Icons.sms_rounded,
                    label: 'Message',
                    color: AppColors.cyan,
                    onTap: c.phone == null ? null : () => _launch(context, Uri(scheme: 'sms', path: c.phone)),
                  ),
                  _Action(
                    icon: Icons.mail_rounded,
                    label: 'Email',
                    color: AppColors.primary,
                    onTap: c.email == null ? null : () => _launch(context, Uri(scheme: 'mailto', path: c.email)),
                  ),
                  _Action(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    color: AppColors.violet,
                    onTap: c.website == null ? null : () => _launch(context, _web(c.website!)),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15),
              const SectionHeader('Contact details'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: c.phone),
                    _InfoRow(icon: Icons.alternate_email_rounded, label: 'Email', value: c.email),
                    _InfoRow(icon: Icons.business_rounded, label: 'Company', value: c.company),
                    _InfoRow(icon: Icons.work_outline_rounded, label: 'Position', value: c.position),
                    _InfoRow(icon: Icons.language_rounded, label: 'Website', value: c.website),
                    _InfoRow(icon: Icons.place_outlined, label: 'Address', value: c.address, last: true),
                  ],
                ),
              ),
              SectionHeader('Meetings · ${c.occurrenceCount}'),
              occurrences.when(
            skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (list) => Column(
                  children: [
                    for (final (i, o) in list.indexed)
                      _MeetingCard(occurrence: o, images: images, isLast: i == list.length - 1)
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 280.ms)
                          .slideX(begin: 0.05),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'First captured ${Fmt.dateTime(c.createdAt)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final c = contact;
    switch (action) {
      case 'edit':
        context.push(Routes.leadEdit(c.id));
      case 'photo':
        final picked = await pickPhoto(context, selfie: true);
        if (picked == null) return;
        final rel = await images.importFile(picked, kind: 'selfie');
        await ref.read(contactRepoProvider).setPhoto(c.id, rel);
        ref.refreshData();
      case 'vcard':
        final box = context.findRenderObject() as RenderBox?;
        await ref.read(exportServiceProvider).shareText(
              '${ExportService.safeFileName(c.fullName)}.vcf',
              ExportService.vcard(c),
              mime: 'text/vcard',
              subject: c.fullName,
              origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
            );
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: 'Erase ${c.firstName}?',
          message: 'This permanently deletes ${c.fullName}, every meeting record and all photos of them '
              'from this device. It cannot be undone.',
          confirmLabel: 'Erase',
          destructive: true,
        );
        if (!ok) return;
        await ref.read(contactRepoProvider).delete(c.id, actorId: ref.read(sessionProvider)?.id);
        ref.refreshData();
        if (context.mounted) {
          showAppSnack(context, '${c.fullName} was erased', icon: Icons.delete_rounded);
          context.pop();
        }
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              IconBadge(icon: icon, color: color, size: 52, iconSize: 22, circle: true),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.trim().isNotEmpty;
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(icon, size: 20, color: has ? AppColors.textSecondary : AppColors.textMuted),
          title: Text(label, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(
            has ? value! : 'Not provided',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: has ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          trailing: has
              ? IconButton(
                  tooltip: 'Copy $label',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value!));
                    showAppSnack(context, '$label copied', icon: Icons.copy_rounded, color: AppColors.cyan);
                  },
                )
              : null,
        ),
        if (!last) const Divider(indent: 56, height: 1),
      ],
    );
  }
}

/// One meeting (occurrence): where, when, how captured, context note,
/// lead temperature and follow-up state.
class _MeetingCard extends ConsumerWidget {
  const _MeetingCard({required this.occurrence, required this.images, required this.isLast});
  final Occurrence occurrence;
  final ImageStore images;
  final bool isLast;

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController(text: occurrence.notes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meeting notes'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: Validators.notesMax,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Save')),
        ],
      ),
    );
    // Not disposed here: the dialog's exit animation still reads it.
    if (saved == null) return;
    await ref.read(contactRepoProvider).updateOccurrence(occurrence.id, notes: saved);
    ref.refreshData();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occurrence;
    final card = images.resolve(o.businessCardPath);
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 10,
            top: 26,
            bottom: 0,
            child: Container(width: 2, color: AppColors.border),
          ),
        Positioned(
          left: 5,
          top: 18,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 8)],
            ),
          ),
        ),
        Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push(Routes.event(o.eventId)),
                            child: Text(
                              o.eventName ?? 'Event',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ),
                        Text(Fmt.dateShort(o.capturedAt), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: o.captureMethod.label,
                          color: AppColors.textSecondary,
                          icon: methodIcon(o.captureMethod),
                          dense: true,
                        ),
                        StatusPill(
                          label: o.duplicateResolution.label,
                          color: resolutionColor(o.duplicateResolution),
                          dense: true,
                        ),
                        if (o.capturedByName != null)
                          StatusPill(
                            label: 'by ${o.capturedByName!.split(' ').first}',
                            color: AppColors.textMuted,
                            icon: Icons.person_outline_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _editNotes(context, ref),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (o.notes ?? '').isEmpty ? 'Add conversation notes…' : o.notes!,
                                style: TextStyle(
                                  color: (o.notes ?? '').isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RatingSelector(
                      value: o.rating,
                      onChanged: (r) async {
                        await ref
                            .read(contactRepoProvider)
                            .updateOccurrence(o.id, rating: r, clearRating: r == null);
                        ref.refreshData();
                      },
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<FollowUpStatus>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: followUpColor(o.followUpStatus).withValues(alpha: 0.22),
                        selectedForegroundColor: followUpColor(o.followUpStatus),
                        side: const BorderSide(color: AppColors.border),
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: FollowUpStatus.pending, label: Text('To do'), icon: Icon(Icons.flag_outlined)),
                        ButtonSegment(value: FollowUpStatus.contacted, label: Text('Contacted')),
                        ButtonSegment(value: FollowUpStatus.done, label: Text('Done')),
                      ],
                      selected: {o.followUpStatus},
                      onSelectionChanged: (s) async {
                        HapticFeedback.selectionClick();
                        await ref.read(contactRepoProvider).updateOccurrence(o.id, followUp: s.first);
                        ref.refreshData();
                      },
                    ),
                    if (card != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => PhotoViewerPage.open(context, card, 'Business card'),
                        child: Hero(
                          tag: card.path,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(card, height: 120, width: double.infinity, fit: BoxFit.cover, cacheWidth: 800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
