import 'dart:io';

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
import '../../data/repositories/contact_repository.dart';

enum _Filter { all, favorites, hot, warm, cold }

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;
  ContactSort _sort = ContactSort.recent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ContactQuery get _q => (
        query: _query,
        favorites: _filter == _Filter.favorites,
        rating: switch (_filter) {
          _Filter.hot => LeadRating.hot,
          _Filter.warm => LeadRating.warm,
          _Filter.cold => LeadRating.cold,
          _ => null,
        },
        sort: _sort,
      );

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider(_q));
    final images = ref.watch(imageStoreProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Leads', style: Theme.of(context).textTheme.headlineMedium)),
                PopupMenuButton<ContactSort>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: ContactSort.recent, child: Text('Recently met')),
                    PopupMenuItem(value: ContactSort.name, child: Text('Name A–Z')),
                    PopupMenuItem(value: ContactSort.company, child: Text('Company')),
                  ],
                ),
                IconButton(
                  tooltip: 'Add lead manually',
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () => context.push(Routes.manual),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, company, email, phone',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 4),
              children: [
                for (final f in _Filter.values) ...[
                  ChoiceChip(
                    label: Text(switch (f) {
                      _Filter.all => 'All',
                      _Filter.favorites => 'Favourites',
                      _Filter.hot => 'Hot',
                      _Filter.warm => 'Warm',
                      _Filter.cold => 'Cold',
                    }),
                    avatar: switch (f) {
                      _Filter.favorites => const Icon(Icons.star_rounded, size: 16, color: AppColors.brandAmber),
                      _Filter.hot => Icon(ratingIcon(LeadRating.hot), size: 16, color: AppColors.hot),
                      _Filter.warm => Icon(ratingIcon(LeadRating.warm), size: 16, color: AppColors.warning),
                      _Filter.cold => Icon(ratingIcon(LeadRating.cold), size: 16, color: AppColors.cyan),
                      _Filter.all => null,
                    },
                    showCheckmark: false,
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refreshData(),
              child: contacts.when(
            skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        EmptyState(
                          icon: _query.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
                          title: _query.isEmpty ? 'No leads yet' : 'No matches',
                          message: _query.isEmpty
                              ? 'Scan a business card or type a contact in to start building your list.'
                              : 'Try a different name, company or email.',
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 24),
                    itemCount: list.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            '${list.length} lead${list.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      final c = list[i - 1];
                      return LeadTile(contact: c, photo: images.resolve(c.photoPath))
                          .animate(delay: (i < 12 ? i * 35 : 0).ms)
                          .fadeIn(duration: 260.ms)
                          .slideY(begin: 0.1);
                    },
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

class LeadTile extends ConsumerWidget {
  const LeadTile({super.key, required this.contact, this.photo});
  final Contact contact;
  final File? photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contact;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push(Routes.lead(c.id)),
        child: Row(
          children: [
            Hero(
              tag: 'avatar-${c.id}',
              child: ContactAvatar(name: c.fullName, photo: photo, size: 50),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      if (c.isFavorite) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.brandAmber),
                      ],
                    ],
                  ),
                  if (c.subtitle.isNotEmpty)
                    Text(
                      c.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            c.lastEventName ?? '—',
                            if (c.occurrenceCount > 1) '${c.occurrenceCount} meetings',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (c.lastSeenAt != null)
                  Text(Fmt.relative(c.lastSeenAt!), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                if (c.lastRating != null)
                  StatusPill(
                    label: c.lastRating!.label,
                    color: ratingColor(c.lastRating),
                    icon: ratingIcon(c.lastRating),
                    dense: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
