import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models/models.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../data/services/card_extraction_service.dart';
import '../data/services/export_service.dart';
import '../data/services/image_store.dart';
import '../data/services/retention_service.dart';

// ---------------------------------------------------------------- core infra

/// Overridden in `main()` with the opened SQLite database.
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError('databaseProvider'));

/// Overridden in `main()` with the app-documents image store.
final imageStoreProvider = Provider<ImageStore>((ref) => throw UnimplementedError('imageStoreProvider'));

final profileRepoProvider = Provider((ref) => ProfileRepository(ref.watch(databaseProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));
final eventRepoProvider = Provider((ref) => EventRepository(ref.watch(databaseProvider)));
final contactRepoProvider = Provider(
  (ref) => ContactRepository(ref.watch(databaseProvider), images: ref.watch(imageStoreProvider)),
);
final statsRepoProvider = Provider((ref) => StatsRepository(ref.watch(databaseProvider)));
final retentionServiceProvider = Provider(
  (ref) => RetentionService(ref.watch(databaseProvider), ref.watch(imageStoreProvider)),
);
final extractionServiceProvider = Provider((ref) => CardExtractionService());
final exportServiceProvider = Provider((ref) => ExportService());

// ---------------------------------------------------------------- session

/// The unlocked local profile, or `null` when the app is locked.
class SessionNotifier extends Notifier<Profile?> {
  @override
  Profile? build() => null;

  void signIn(Profile p) => state = p;
  void signOut() => state = null;
  void refresh(Profile p) {
    if (state?.id == p.id) state = p;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Profile?>(SessionNotifier.new);

// ---------------------------------------------------------------- data revision

/// Bumped after every write so dependent queries re-run.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(DataRevision.new);

extension DataRefresh on WidgetRef {
  void refreshData() => read(dataRevisionProvider.notifier).bump();
}

extension AsyncValueX<T> on AsyncValue<T> {
  /// The latest data (kept while refreshing), or `null` while loading/error.
  T? get dataOrNull => when(
        skipLoadingOnReload: true,
        data: (d) => d,
        loading: () => null,
        error: (_, _) => null,
      );
}

// ---------------------------------------------------------------- queries

typedef EventQuery = ({EventFilter filter, String query});

final eventsProvider = FutureProvider.autoDispose.family<List<Event>, EventQuery>((ref, q) {
  ref.watch(dataRevisionProvider);
  return ref.watch(eventRepoProvider).list(filter: q.filter, query: q.query);
});

final activeEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(eventRepoProvider).list();
});

final eventProvider = FutureProvider.autoDispose.family<Event?, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(eventRepoProvider).get(id);
});

final eventOccurrencesProvider = FutureProvider.autoDispose.family<List<Occurrence>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepoProvider).occurrencesForEvent(id);
});

final eventStatsProvider = FutureProvider.autoDispose.family<EventStats, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(statsRepoProvider).forEvent(id);
});

/// The event captures are attributed to. Falls back to `null` when the
/// stored event was archived.
final currentEventProvider = FutureProvider.autoDispose<Event?>((ref) async {
  ref.watch(dataRevisionProvider);
  final settings = ref.watch(settingsRepoProvider);
  final events = ref.watch(eventRepoProvider);
  final id = await settings.get(SettingsRepository.kCurrentEventId);
  if (id == null) return null;
  final e = await events.get(id);
  if (e == null || e.isArchived) return null;
  return e;
});

typedef ContactQuery = ({String query, bool favorites, LeadRating? rating, ContactSort sort});

final contactsProvider = FutureProvider.autoDispose.family<List<Contact>, ContactQuery>((ref, q) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepoProvider).list(
        query: q.query,
        favoritesOnly: q.favorites,
        rating: q.rating,
        sort: q.sort,
      );
});

final contactProvider = FutureProvider.autoDispose.family<Contact?, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepoProvider).get(id);
});

final contactOccurrencesProvider = FutureProvider.autoDispose.family<List<Occurrence>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepoProvider).occurrencesForContact(id);
});

final recentOccurrencesProvider = FutureProvider.autoDispose<List<Occurrence>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(contactRepoProvider).recentOccurrences(limit: 6);
});

final dashboardProvider = FutureProvider.autoDispose<DashboardStats>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(statsRepoProvider).dashboard();
});

final profilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(profileRepoProvider).list();
});

final storageStatsProvider = FutureProvider.autoDispose<(StorageStats, int)>((ref) async {
  ref.watch(dataRevisionProvider);
  final statsRepo = ref.watch(statsRepoProvider);
  final images = ref.watch(imageStoreProvider);
  final stats = await statsRepo.storage();
  final bytes = await images.totalBytes();
  return (stats, bytes);
});

final retentionDaysProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(settingsRepoProvider).retentionDays();
});

final autoLockMinutesProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(settingsRepoProvider).autoLockMinutes();
});
