import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class DailyCount {
  const DailyCount(this.day, this.count);
  final DateTime day;
  final int count;
}

class DashboardStats {
  const DashboardStats({
    required this.totalContacts,
    required this.activeEvents,
    required this.capturesToday,
    required this.capturesThisWeek,
    required this.hotLeads,
    required this.pendingFollowUps,
    required this.last7Days,
    required this.byMethod,
  });

  final int totalContacts;
  final int activeEvents;
  final int capturesToday;
  final int capturesThisWeek;
  final int hotLeads;
  final int pendingFollowUps;
  final List<DailyCount> last7Days;
  final Map<CaptureMethod, int> byMethod;

  static const empty = DashboardStats(
    totalContacts: 0,
    activeEvents: 0,
    capturesToday: 0,
    capturesThisWeek: 0,
    hotLeads: 0,
    pendingFollowUps: 0,
    last7Days: [],
    byMethod: {},
  );
}

class EventStats {
  const EventStats({
    required this.total,
    required this.newContacts,
    required this.returning,
    required this.hot,
    required this.followedUp,
    required this.byMethod,
  });

  final int total;
  final int newContacts;
  final int returning;
  final int hot;
  final int followedUp;
  final Map<CaptureMethod, int> byMethod;
}

class StorageStats {
  const StorageStats({
    required this.profiles,
    required this.events,
    required this.contacts,
    required this.occurrences,
    required this.auditEvents,
  });
  final int profiles;
  final int events;
  final int contacts;
  final int occurrences;
  final int auditEvents;
}

class StatsRepository {
  StatsRepository(this._db);
  final Database _db;

  Future<int> _int(String sql, [List<Object?> args = const []]) async =>
      Sqflite.firstIntValue(await _db.rawQuery(sql, args)) ?? 0;

  Future<DashboardStats> dashboard({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final startToday = DateTime(n.year, n.month, n.day);
    final start7 = startToday.subtract(const Duration(days: 6));

    final occ = await _db.rawQuery(
      'SELECT captured_at, capture_method FROM event_occurrences WHERE captured_at >= ?',
      [start7.toUtc().toIso8601String()],
    );

    final buckets = List<int>.filled(7, 0);
    var today = 0;
    for (final r in occ) {
      final t = DateTime.parse(r['captured_at'] as String).toLocal();
      final dayIndex = DateTime(t.year, t.month, t.day).difference(start7).inDays;
      if (dayIndex >= 0 && dayIndex < 7) buckets[dayIndex]++;
      if (!t.isBefore(startToday)) today++;
    }

    final methodRows = await _db.rawQuery(
      'SELECT capture_method, COUNT(*) AS n FROM event_occurrences GROUP BY capture_method',
    );

    return DashboardStats(
      totalContacts: await _int('SELECT COUNT(*) FROM contacts'),
      activeEvents: await _int("SELECT COUNT(*) FROM events WHERE status = 'active'"),
      capturesToday: today,
      capturesThisWeek: occ.length,
      hotLeads: await _int("SELECT COUNT(*) FROM event_occurrences WHERE rating = 'hot'"),
      pendingFollowUps:
          await _int("SELECT COUNT(*) FROM event_occurrences WHERE follow_up_status = 'pending'"),
      last7Days: [
        for (var i = 0; i < 7; i++) DailyCount(start7.add(Duration(days: i)), buckets[i]),
      ],
      byMethod: {
        for (final r in methodRows)
          CaptureMethod.fromDb(r['capture_method'] as String?): (r['n'] as int?) ?? 0,
      },
    );
  }

  Future<EventStats> forEvent(String eventId) async {
    final rows = await _db.rawQuery(
      'SELECT capture_method, duplicate_resolution, rating, follow_up_status '
      'FROM event_occurrences WHERE event_id = ?',
      [eventId],
    );
    var newC = 0, ret = 0, hot = 0, fu = 0;
    final byMethod = <CaptureMethod, int>{};
    for (final r in rows) {
      if (r['duplicate_resolution'] == 'new') {
        newC++;
      } else {
        ret++;
      }
      if (r['rating'] == 'hot') hot++;
      if (r['follow_up_status'] != 'pending') fu++;
      final m = CaptureMethod.fromDb(r['capture_method'] as String?);
      byMethod[m] = (byMethod[m] ?? 0) + 1;
    }
    return EventStats(
      total: rows.length,
      newContacts: newC,
      returning: ret,
      hot: hot,
      followedUp: fu,
      byMethod: byMethod,
    );
  }

  Future<StorageStats> storage() async => StorageStats(
        profiles: await _int('SELECT COUNT(*) FROM profiles'),
        events: await _int('SELECT COUNT(*) FROM events'),
        contacts: await _int('SELECT COUNT(*) FROM contacts'),
        occurrences: await _int('SELECT COUNT(*) FROM event_occurrences'),
        auditEvents: await _int('SELECT COUNT(*) FROM audit_events'),
      );
}
