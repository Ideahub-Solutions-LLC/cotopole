import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Append-only local audit trail (who did what, when). Never stores contact
/// field values — only identifiers — so it does not become a second copy of
/// personal data (cf. GAP SEC-03).
abstract final class AuditLog {
  static Future<void> write(
    DatabaseExecutor db,
    String type,
    String? actorId,
    Map<String, Object?>? metadata,
  ) async {
    await db.insert('audit_events', {
      'event_type': type,
      'actor_profile_id': actorId,
      'metadata': metadata == null ? null : jsonEncode(metadata),
      'created_at': isoNow(),
    });
  }
}
