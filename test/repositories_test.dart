import 'dart:io';

import 'package:cotopole/data/database/app_database.dart';
import 'package:cotopole/data/models/models.dart';
import 'package:cotopole/data/repositories/contact_repository.dart';
import 'package:cotopole/data/repositories/event_repository.dart';
import 'package:cotopole/data/repositories/profile_repository.dart';
import 'package:cotopole/data/repositories/stats_repository.dart';
import 'package:cotopole/data/services/image_store.dart';
import 'package:cotopole/data/services/retention_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late EventRepository events;
  late ContactRepository contacts;
  late ProfileRepository profiles;
  late Event expo;

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    events = EventRepository(db);
    contacts = ContactRepository(db);
    profiles = ProfileRepository(db);
    expo = (await events.create(name: 'Dental Expo', startsAt: DateTime(2026, 11, 18, 9))).event;
  });

  tearDown(() async => db.close());

  CaptureRequest req(ContactDraft d, {String? eventId, String? resolveTo, bool forceNew = false}) =>
      CaptureRequest(
        eventId: eventId ?? expo.id,
        draft: d,
        method: CaptureMethod.manual,
        resolveToContactId: resolveTo,
        forceNewContact: forceNew,
      );

  group('Events', () {
    test('creating a duplicate active event returns the existing one (EVT-0005)', () async {
      final r = await events.create(name: '  dental   EXPO ', startsAt: DateTime(2026, 11, 18, 15));
      expect(r.existed, isTrue);
      expect(r.event.id, expo.id);

      final other = await events.create(name: 'Dental Expo', startsAt: DateTime(2026, 11, 19));
      expect(other.existed, isFalse);
    });

    test('editing into a collision is rejected, not merged (EVT-0007)', () async {
      final other = (await events.create(name: 'Tech Summit', startsAt: DateTime(2026, 11, 18))).event;
      await expectLater(
        events.update(other, name: 'Dental Expo', startsAt: DateTime(2026, 11, 18, 11)),
        throwsA(isA<EventConflictException>()),
      );
    });

    test('archived events reject captures', () async {
      await events.setArchived(expo, true);
      await expectLater(
        contacts.capture(req(const ContactDraft(firstName: 'A', lastName: 'B', email: 'a@b.co'))),
        throwsA(isA<ArchivedEventException>()),
      );
    });

    test('list filters and counts captures', () async {
      await contacts.capture(req(const ContactDraft(firstName: 'A', lastName: 'B', email: 'a@b.co')));
      final active = await events.list();
      expect(active.single.contactCount, 1);
      await events.setArchived(expo, true);
      expect(await events.list(), isEmpty);
      expect(await events.list(filter: EventFilter.archived), hasLength(1));
    });
  });

  group('Capture pipeline & duplicate detection', () {
    test('new contact, then phone match on a re-capture', () async {
      final first = await contacts.capture(
        req(const ContactDraft(firstName: 'jane', lastName: 'doe', phone: '+1 (555) 123-4567')),
      );
      expect(first.resolution, DuplicateResolution.newContact);

      final second = await contacts.capture(
        req(const ContactDraft(firstName: 'Jane', lastName: 'Doe', phone: '15551234567', email: 'jane@acme.com')),
      );
      expect(second.resolution, DuplicateResolution.phoneMatch);
      expect(second.contact.id, first.contact.id);
      expect(second.alreadyMetAtEvent, isTrue);
      // Blank email was filled in, nothing overwritten.
      expect(second.contact.email, 'jane@acme.com');
      expect(second.contact.occurrenceCount, 2);
    });

    test('email match when there is no phone match', () async {
      final a = await contacts.capture(req(const ContactDraft(firstName: 'A', lastName: 'B', email: 'Ann@X.com')));
      final b = await contacts.capture(
        req(const ContactDraft(firstName: 'Ann', lastName: 'B', phone: '0917 000 0000', email: 'ann@x.com')),
      );
      expect(b.resolution, DuplicateResolution.emailMatch);
      expect(b.contact.id, a.contact.id);
    });

    test('ambiguous duplicates stop and save nothing; organiser can resolve', () async {
      await contacts.capture(req(const ContactDraft(firstName: 'A', lastName: 'One', phone: '028123000'), forceNew: true));
      await contacts.capture(req(const ContactDraft(firstName: 'B', lastName: 'Two', phone: '028123000'), forceNew: true));

      final before = await contacts.list();
      AmbiguousDuplicateException? caught;
      try {
        await contacts.capture(req(const ContactDraft(firstName: 'C', lastName: 'Three', phone: '02 8123 000')));
      } on AmbiguousDuplicateException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.candidates, hasLength(2));
      expect(caught.onPhone, isTrue);
      expect(await contacts.list(), hasLength(before.length));

      final resolved = await contacts.capture(
        req(const ContactDraft(firstName: 'C', lastName: 'Three', phone: '028123000'),
            resolveTo: caught.candidates.first.id),
      );
      expect(resolved.resolution, DuplicateResolution.adminResolved);
    });

    test('contacts are global: one person, many events', () async {
      final summit = (await events.create(name: 'Summit', startsAt: DateTime(2026, 12, 1))).event;
      await contacts.capture(req(const ContactDraft(firstName: 'P', lastName: 'Q', email: 'p@q.io')));
      await contacts.capture(req(const ContactDraft(firstName: 'P', lastName: 'Q', email: 'p@q.io'), eventId: summit.id));
      final all = await contacts.list();
      expect(all, hasLength(1));
      expect(all.single.occurrenceCount, 2);
      expect(await contacts.occurrencesForContact(all.single.id), hasLength(2));
    });

    test('erasing a contact removes its meetings', () async {
      final r = await contacts.capture(req(const ContactDraft(firstName: 'X', lastName: 'Y', email: 'x@y.io')));
      await contacts.delete(r.contact.id);
      expect(await contacts.get(r.contact.id), isNull);
      expect(await contacts.occurrencesForEvent(expo.id), isEmpty);
    });

    test('search and rating filter', () async {
      await contacts.capture(CaptureRequest(
        eventId: expo.id,
        draft: const ContactDraft(firstName: 'Hot', lastName: 'Lead', email: 'h@l.io', company: 'Globex'),
        method: CaptureMethod.image,
        rating: LeadRating.hot,
      ));
      await contacts.capture(req(const ContactDraft(firstName: 'Cold', lastName: 'Lead', email: 'c@l.io')));
      expect(await contacts.list(query: 'globex'), hasLength(1));
      expect(await contacts.list(rating: LeadRating.hot), hasLength(1));
      final stats = await StatsRepository(db).forEvent(expo.id);
      expect(stats.total, 2);
      expect(stats.hot, 1);
      expect(stats.byMethod[CaptureMethod.image], 1);
    });
  });

  group('Profiles & PIN', () {
    test('verifies PIN and locks out after repeated failures', () async {
      final p = await profiles.create(displayName: 'Org', role: UserRole.admin, pin: '482915');
      expect(await profiles.verifyPin(p.id, '482915'), isA<PinOk>());
      for (var i = 0; i < ProfileRepository.maxAttempts - 1; i++) {
        expect(await profiles.verifyPin(p.id, '000000'), isA<PinWrong>());
      }
      expect(await profiles.verifyPin(p.id, '000000'), isA<PinLocked>());
      // Even the right PIN is refused while locked.
      expect(await profiles.verifyPin(p.id, '482915'), isA<PinLocked>());
      final later = DateTime.now().add(ProfileRepository.lockDuration + const Duration(seconds: 1));
      expect(await profiles.verifyPin(p.id, '482915', now: later), isA<PinOk>());
    });

    test('PIN is never stored in plain text', () async {
      final p = await profiles.create(displayName: 'Org', role: UserRole.admin, pin: '482915');
      expect(p.pinHash, isNot(contains('482915')));
    });

    test('the last organiser cannot be removed', () async {
      final admin = await profiles.create(displayName: 'Org', role: UserRole.admin, pin: '482915');
      await expectLater(profiles.delete(admin.id, actorId: admin.id), throwsStateError);
    });
  });

  test('retention purges old photos but keeps the lead', () async {
    final dir = await Directory.systemTemp.createTemp('cotopole_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = ImageStore(dir.path);
    final src = File('${dir.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
    final rel = await store.importFile(src.path, kind: 'card');

    final repo = ContactRepository(db, images: store);
    final r = await repo.capture(CaptureRequest(
      eventId: expo.id,
      draft: const ContactDraft(firstName: 'Old', lastName: 'Card', email: 'o@c.io'),
      method: CaptureMethod.image,
      businessCardPath: rel,
    ));
    // Backdate the capture by 40 days.
    await db.update(
      'event_occurrences',
      {'captured_at': DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [r.occurrenceId],
    );

    final removed = await RetentionService(db, store).purge(days: 30);
    expect(removed, 1);
    expect(store.resolve(rel), isNull);
    expect(await repo.get(r.contact.id), isNotNull);
  });
}
