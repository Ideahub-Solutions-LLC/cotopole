import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/normalizers.dart';
import '../models/models.dart';
import '../services/image_store.dart';
import 'audit_log.dart';

enum ContactSort { recent, name, company }

/// Outcome of running duplicate detection on a draft.
sealed class MatchResult {
  const MatchResult();
}

class NoMatch extends MatchResult {
  const NoMatch();
}

class SingleMatch extends MatchResult {
  const SingleMatch(this.contact, this.resolution);
  final Contact contact;
  final DuplicateResolution resolution; // phoneMatch | emailMatch
}

class AmbiguousMatch extends MatchResult {
  const AmbiguousMatch(this.candidates, {required this.onPhone});
  final List<Contact> candidates;
  final bool onPhone;
}

/// More than one existing contact shares this phone/email. Nothing was saved.
class AmbiguousDuplicateException implements Exception {
  const AmbiguousDuplicateException(this.candidates, {required this.onPhone});
  final List<Contact> candidates;
  final bool onPhone;

  @override
  String toString() =>
      '${candidates.length} existing contacts share this ${onPhone ? 'phone number' : 'email'}.';
}

class ArchivedEventException implements Exception {
  const ArchivedEventException();
  @override
  String toString() => 'This event is archived and no longer accepts captures.';
}

class CaptureRequest {
  const CaptureRequest({
    required this.eventId,
    required this.draft,
    required this.method,
    this.notes,
    this.rating,
    this.businessCardPath,
    this.selfiePath,
    this.ocrRawText,
    this.capturedByProfileId,
    this.resolveToContactId,
    this.forceNewContact = false,
  });

  final String eventId;
  final ContactDraft draft;
  final CaptureMethod method;
  final String? notes;
  final LeadRating? rating;
  final String? businessCardPath;
  final String? selfiePath;
  final String? ocrRawText;
  final String? capturedByProfileId;

  /// Organiser override for an ambiguous match: attach to this contact.
  final String? resolveToContactId;

  /// Organiser override for an ambiguous match: create a separate person.
  final bool forceNewContact;
}

class CaptureResult {
  const CaptureResult({
    required this.contact,
    required this.occurrenceId,
    required this.resolution,
    required this.alreadyMetAtEvent,
  });

  final Contact contact;
  final String occurrenceId;
  final DuplicateResolution resolution;

  /// The person already had an occurrence at this event before this capture.
  final bool alreadyMetAtEvent;
}

class ContactRepository {
  ContactRepository(this._db, {this.images});
  final Database _db;
  final ImageStore? images;

  static const _listSelect = '''
    SELECT c.*,
      (SELECT COUNT(*) FROM event_occurrences o WHERE o.contact_id = c.id) AS occurrence_count,
      (SELECT MAX(o.captured_at) FROM event_occurrences o WHERE o.contact_id = c.id) AS last_seen_at,
      (SELECT e.name FROM event_occurrences o JOIN events e ON e.id = o.event_id
         WHERE o.contact_id = c.id ORDER BY o.captured_at DESC LIMIT 1) AS last_event_name,
      (SELECT o.rating FROM event_occurrences o
         WHERE o.contact_id = c.id ORDER BY o.captured_at DESC LIMIT 1) AS last_rating
    FROM contacts c
  ''';

  static const _occSelect = '''
    SELECT o.*, e.name AS event_name,
      (c.first_name || ' ' || c.last_name) AS contact_name,
      c.company AS contact_company,
      c.photo_path AS contact_photo_path,
      p.display_name AS captured_by_name
    FROM event_occurrences o
    JOIN events e ON e.id = o.event_id
    JOIN contacts c ON c.id = o.contact_id
    LEFT JOIN profiles p ON p.id = o.captured_by_profile_id
  ''';

  // ---------------------------------------------------------------- queries

  Future<List<Contact>> list({
    String query = '',
    String? eventId,
    bool favoritesOnly = false,
    LeadRating? rating,
    ContactSort sort = ContactSort.recent,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('''(
        (c.first_name || ' ' || c.last_name) LIKE ? OR c.company LIKE ? OR
        c.email LIKE ? OR c.phone LIKE ? OR c.position LIKE ?
      )''');
      final like = '%$q%';
      args.addAll([like, like, like, like, like]);
    }
    if (eventId != null) {
      where.add('EXISTS (SELECT 1 FROM event_occurrences o WHERE o.contact_id = c.id AND o.event_id = ?)');
      args.add(eventId);
    }
    if (favoritesOnly) where.add('c.is_favorite = 1');
    if (rating != null) {
      where.add('''(SELECT o.rating FROM event_occurrences o WHERE o.contact_id = c.id
        ORDER BY o.captured_at DESC LIMIT 1) = ?''');
      args.add(rating.db);
    }
    final sql = StringBuffer(_listSelect);
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(switch (sort) {
      ContactSort.recent => ' ORDER BY COALESCE(last_seen_at, c.created_at) DESC',
      ContactSort.name => ' ORDER BY c.first_name COLLATE NOCASE, c.last_name COLLATE NOCASE',
      ContactSort.company => " ORDER BY COALESCE(NULLIF(c.company, ''), 'zzz') COLLATE NOCASE, c.first_name",
    });
    final rows = await _db.rawQuery(sql.toString(), args);
    return rows.map(Contact.fromRow).toList();
  }

  Future<Contact?> get(String id) async {
    final rows = await _db.rawQuery('$_listSelect WHERE c.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : Contact.fromRow(rows.first);
  }

  Future<List<Occurrence>> occurrencesForContact(String contactId) async {
    final rows = await _db.rawQuery(
      '$_occSelect WHERE o.contact_id = ? ORDER BY o.captured_at DESC',
      [contactId],
    );
    return rows.map(Occurrence.fromRow).toList();
  }

  Future<List<Occurrence>> occurrencesForEvent(String eventId) async {
    final rows = await _db.rawQuery(
      '$_occSelect WHERE o.event_id = ? ORDER BY o.captured_at DESC',
      [eventId],
    );
    return rows.map(Occurrence.fromRow).toList();
  }

  Future<List<Occurrence>> recentOccurrences({int limit = 8}) async {
    final rows = await _db.rawQuery('$_occSelect ORDER BY o.captured_at DESC LIMIT ?', [limit]);
    return rows.map(Occurrence.fromRow).toList();
  }

  Future<List<Occurrence>> allOccurrences() async {
    final rows = await _db.rawQuery('$_occSelect ORDER BY o.captured_at DESC');
    return rows.map(Occurrence.fromRow).toList();
  }

  // ------------------------------------------------------ duplicate detection

  /// Deterministic duplicate detection: normalized phone first, then
  /// normalized email. Exactly one match → that contact. Several → ambiguous.
  Future<MatchResult> findMatch(ContactDraft draft, {DatabaseExecutor? executor}) async {
    final db = executor ?? _db;
    final phone = Normalizers.phone(draft.phone);
    if (phone != null) {
      final rows = await db.rawQuery('$_listSelect WHERE c.phone_normalized = ?', [phone]);
      if (rows.length == 1) {
        return SingleMatch(Contact.fromRow(rows.first), DuplicateResolution.phoneMatch);
      }
      if (rows.length > 1) {
        return AmbiguousMatch(rows.map(Contact.fromRow).toList(), onPhone: true);
      }
    }
    final email = Normalizers.email(draft.email);
    if (email != null) {
      final rows = await db.rawQuery('$_listSelect WHERE c.email_normalized = ?', [email]);
      if (rows.length == 1) {
        return SingleMatch(Contact.fromRow(rows.first), DuplicateResolution.emailMatch);
      }
      if (rows.length > 1) {
        return AmbiguousMatch(rows.map(Contact.fromRow).toList(), onPhone: false);
      }
    }
    return const NoMatch();
  }

  // ----------------------------------------------------------------- capture

  /// The single capture pipeline used by manual entry, card scan and QR.
  /// Every capture produces exactly one occurrence row; the contact is
  /// created or matched by duplicate detection, all in one transaction.
  Future<CaptureResult> capture(CaptureRequest req) async {
    return _db.transaction((txn) async {
      final ev = await txn.query('events', where: 'id = ?', whereArgs: [req.eventId], limit: 1);
      if (ev.isEmpty) throw StateError('Event not found');
      if (ev.first['status'] == 'archived') throw const ArchivedEventException();

      final now = isoNow();
      final draft = _clean(req.draft);
      String contactId;
      DuplicateResolution resolution;

      if (req.resolveToContactId != null) {
        contactId = req.resolveToContactId!;
        resolution = DuplicateResolution.adminResolved;
        await _fillMissing(txn, contactId, draft, req.selfiePath, now);
      } else if (req.forceNewContact) {
        contactId = await _insertContact(txn, draft, req.selfiePath, req.capturedByProfileId, now);
        resolution = DuplicateResolution.adminResolved;
      } else {
        final match = await findMatch(draft, executor: txn);
        switch (match) {
          case AmbiguousMatch(:final candidates, :final onPhone):
            throw AmbiguousDuplicateException(candidates, onPhone: onPhone);
          case SingleMatch(:final contact, resolution: final r):
            contactId = contact.id;
            resolution = r;
            await _fillMissing(txn, contactId, draft, req.selfiePath, now);
          case NoMatch():
            contactId = await _insertContact(txn, draft, req.selfiePath, req.capturedByProfileId, now);
            resolution = DuplicateResolution.newContact;
        }
      }

      final metBefore = (Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM event_occurrences WHERE event_id = ? AND contact_id = ?',
                [req.eventId, contactId],
              )) ??
              0) >
          0;

      final occId = const Uuid().v4();
      final notes = req.notes?.trim();
      await txn.insert('event_occurrences', {
        'id': occId,
        'event_id': req.eventId,
        'contact_id': contactId,
        'captured_at': now,
        'capture_method': req.method.db,
        'duplicate_resolution': resolution.db,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'rating': req.rating?.db,
        'follow_up_status': FollowUpStatus.pending.db,
        'business_card_path': req.businessCardPath,
        'selfie_path': req.selfiePath,
        'ocr_raw_text': req.ocrRawText,
        'captured_by_profile_id': req.capturedByProfileId,
        'created_at': now,
        'updated_at': now,
      });
      await AuditLog.write(txn, 'capture.created', req.capturedByProfileId, {
        'occurrence_id': occId,
        'contact_id': contactId,
        'event_id': req.eventId,
        'method': req.method.db,
        'resolution': resolution.db,
      });

      final rows = await txn.rawQuery('$_listSelect WHERE c.id = ? LIMIT 1', [contactId]);
      return CaptureResult(
        contact: Contact.fromRow(rows.first),
        occurrenceId: occId,
        resolution: resolution,
        alreadyMetAtEvent: metBefore,
      );
    });
  }

  Future<String> _insertContact(
    DatabaseExecutor txn,
    ContactDraft d,
    String? photoPath,
    String? createdBy,
    String now,
  ) async {
    final id = const Uuid().v4();
    await txn.insert('contacts', {
      'id': id,
      ..._draftRow(d),
      'photo_path': photoPath,
      'is_favorite': 0,
      'created_by_profile_id': createdBy,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  /// A match updates the existing person, but only fills fields that are
  /// blank — a capture never silently overwrites known-good data.
  Future<void> _fillMissing(
    DatabaseExecutor txn,
    String contactId,
    ContactDraft incoming,
    String? photoPath,
    String now,
  ) async {
    final rows = await txn.query('contacts', where: 'id = ?', whereArgs: [contactId], limit: 1);
    if (rows.isEmpty) throw StateError('Contact not found');
    final existing = Contact.fromRow(rows.first);
    final merged = existing.toDraft().mergeMissing(incoming);
    await txn.update(
      'contacts',
      {
        ..._draftRow(merged),
        if (existing.photoPath == null && photoPath != null) 'photo_path': photoPath,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  // ------------------------------------------------------------------ edits

  Future<void> update(String id, ContactDraft draft, {String? actorId}) async {
    await _db.update(
      'contacts',
      {..._draftRow(_clean(draft)), 'updated_at': isoNow()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await AuditLog.write(_db, 'contact.updated', actorId, {'contact_id': id});
  }

  Future<void> setFavorite(String id, bool value) async {
    await _db.update('contacts', {'is_favorite': value ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPhoto(String id, String? relativePath) async {
    final old = await get(id);
    await _db.update(
      'contacts',
      {'photo_path': relativePath, 'updated_at': isoNow()},
      where: 'id = ?',
      whereArgs: [id],
    );
    // Only delete the old file if no occurrence still references it.
    final oldPath = old?.photoPath;
    if (oldPath != null && oldPath != relativePath) {
      final refs = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM event_occurrences WHERE selfie_path = ?',
            [oldPath],
          )) ??
          0;
      if (refs == 0) await images?.delete(oldPath);
    }
  }

  Future<void> updateOccurrence(
    String occurrenceId, {
    String? notes,
    LeadRating? rating,
    bool clearRating = false,
    FollowUpStatus? followUp,
  }) async {
    final values = <String, Object?>{'updated_at': isoNow()};
    if (notes != null) values['notes'] = notes.trim().isEmpty ? null : notes.trim();
    if (rating != null || clearRating) values['rating'] = rating?.db;
    if (followUp != null) values['follow_up_status'] = followUp.db;
    await _db.update('event_occurrences', values, where: 'id = ?', whereArgs: [occurrenceId]);
  }

  Future<void> deleteOccurrence(String occurrenceId, {String? actorId}) async {
    final rows = await _db.query('event_occurrences', where: 'id = ?', whereArgs: [occurrenceId]);
    if (rows.isEmpty) return;
    await _db.delete('event_occurrences', where: 'id = ?', whereArgs: [occurrenceId]);
    await images?.delete(rows.first['business_card_path'] as String?);
    final selfie = rows.first['selfie_path'] as String?;
    if (selfie != null) {
      final stillUsed = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM contacts WHERE photo_path = ?',
            [selfie],
          )) ??
          0;
      if (stillUsed == 0) await images?.delete(selfie);
    }
    await AuditLog.write(_db, 'occurrence.deleted', actorId, {'occurrence_id': occurrenceId});
  }

  /// Erases a person and every meeting record and photo of them — the
  /// data-subject deletion right the backend lacks (GAP SEC-04).
  Future<void> delete(String id, {String? actorId}) async {
    final occ = await _db.query('event_occurrences', where: 'contact_id = ?', whereArgs: [id]);
    final contact = await _db.query('contacts', where: 'id = ?', whereArgs: [id]);
    final paths = <String?>{
      for (final o in occ) ...[o['business_card_path'] as String?, o['selfie_path'] as String?],
      if (contact.isNotEmpty) contact.first['photo_path'] as String?,
    };
    await _db.delete('contacts', where: 'id = ?', whereArgs: [id]); // cascades occurrences
    for (final p in paths) {
      await images?.delete(p);
    }
    await AuditLog.write(_db, 'contact.erased', actorId, {'contact_id': id});
  }

  // ----------------------------------------------------------------- helpers

  static ContactDraft _clean(ContactDraft d) => ContactDraft(
        firstName: Normalizers.smartCase(d.firstName),
        lastName: Normalizers.smartCase(d.lastName),
        phone: d.phone.trim(),
        email: d.email.trim().toLowerCase(),
        company: d.company.trim(),
        position: d.position.trim(),
        website: d.website.trim(),
        address: d.address.trim(),
      );

  static Map<String, Object?> _draftRow(ContactDraft d) {
    String? n(String s) => s.trim().isEmpty ? null : s.trim();
    return {
      'first_name': d.firstName.trim(),
      'last_name': d.lastName.trim(),
      'phone': n(d.phone),
      'phone_normalized': Normalizers.phone(d.phone),
      'email': n(d.email),
      'email_normalized': Normalizers.email(d.email),
      'company': n(d.company),
      'position': n(d.position),
      'website': n(d.website),
      'address': n(d.address),
    };
  }
}
