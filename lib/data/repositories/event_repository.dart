import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/normalizers.dart';
import '../models/models.dart';
import 'audit_log.dart';

enum EventFilter { active, archived, all }

/// Thrown when an edit would make an event collide with another active event
/// on name + calendar date (EVT-0007): rejected, never merged.
class EventConflictException implements Exception {
  const EventConflictException(this.existing);
  final Event existing;

  @override
  String toString() => 'An active event named "${existing.name}" already exists on that date.';
}

class CreateEventResult {
  const CreateEventResult(this.event, {required this.existed});
  final Event event;

  /// True when an active event already matched on name + date and was
  /// returned instead of creating a duplicate (EVT-0005).
  final bool existed;
}

class EventRepository {
  EventRepository(this._db);
  final Database _db;

  static const _select = '''
    SELECT e.*,
      (SELECT COUNT(*) FROM event_occurrences o WHERE o.event_id = e.id) AS contact_count
    FROM events e
  ''';

  Future<List<Event>> list({EventFilter filter = EventFilter.active, String query = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    switch (filter) {
      case EventFilter.active:
        where.add("e.status = 'active'");
      case EventFilter.archived:
        where.add("e.status = 'archived'");
      case EventFilter.all:
        break;
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add('(e.name LIKE ? OR e.location LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }
    final sql = StringBuffer(_select);
    if (where.isNotEmpty) sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(' ORDER BY e.starts_at DESC');
    final rows = await _db.rawQuery(sql.toString(), args);
    return rows.map(Event.fromRow).toList();
  }

  Future<Event?> get(String id) async {
    final rows = await _db.rawQuery('$_select WHERE e.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : Event.fromRow(rows.first);
  }

  Future<Event?> _findActiveDuplicate(String name, DateTime startsAt, {String? excludeId}) async {
    final rows = await _db.query(
      'events',
      where: "name_key = ? AND status = 'active'${excludeId != null ? ' AND id != ?' : ''}",
      whereArgs: [_nameKey(name), if (excludeId != null) excludeId],
    );
    for (final r in rows) {
      final e = Event.fromRow(r);
      if (Fmt.sameDay(e.startsAt, startsAt)) return e;
    }
    return null;
  }

  Future<CreateEventResult> create({
    required String name,
    required DateTime startsAt,
    String? location,
    String? notes,
    String? ownerProfileId,
  }) async {
    final existing = await _findActiveDuplicate(name, startsAt);
    if (existing != null) return CreateEventResult(existing, existed: true);

    final now = DateTime.now();
    final e = Event(
      id: const Uuid().v4(),
      name: name.trim(),
      startsAt: startsAt,
      location: _blank(location),
      notes: _blank(notes),
      status: EventStatus.active,
      ownerProfileId: ownerProfileId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('events', {...e.toRow(), 'name_key': _nameKey(e.name)});
    await AuditLog.write(_db, 'event.created', ownerProfileId, {'event_id': e.id});
    return CreateEventResult(e, existed: false);
  }

  Future<Event> update(
    Event e, {
    required String name,
    required DateTime startsAt,
    String? location,
    String? notes,
    String? actorId,
  }) async {
    if (!e.isArchived) {
      final clash = await _findActiveDuplicate(name, startsAt, excludeId: e.id);
      if (clash != null) throw EventConflictException(clash);
    }
    await _db.update(
      'events',
      {
        'name': name.trim(),
        'name_key': _nameKey(name),
        'starts_at': toIso(startsAt),
        'location': _blank(location),
        'notes': _blank(notes),
        'updated_at': isoNow(),
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
    await AuditLog.write(_db, 'event.updated', actorId, {'event_id': e.id});
    return (await get(e.id))!;
  }

  /// Archiving rejects further captures; existing occurrences stay readable.
  Future<void> setArchived(Event e, bool archived, {String? actorId}) async {
    if (!archived) {
      final clash = await _findActiveDuplicate(e.name, e.startsAt, excludeId: e.id);
      if (clash != null) throw EventConflictException(clash);
    }
    await _db.update(
      'events',
      {'status': archived ? 'archived' : 'active', 'updated_at': isoNow()},
      where: 'id = ?',
      whereArgs: [e.id],
    );
    await AuditLog.write(
      _db,
      archived ? 'event.archived' : 'event.restored',
      actorId,
      {'event_id': e.id},
    );
  }

  static String _nameKey(String name) => Normalizers.eventNameKey(name);
  static String? _blank(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}
