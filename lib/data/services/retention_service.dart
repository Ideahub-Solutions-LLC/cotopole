import 'package:sqflite/sqflite.dart';

import '../repositories/audit_log.dart';
import 'image_store.dart';

/// Enforces the photo-retention policy on device (GAP COR-08: the stated
/// 30-day retention was enforced nowhere). Card photos and client selfies
/// older than the configured window are deleted; the contact record and the
/// meeting notes are kept.
class RetentionService {
  RetentionService(this._db, this._images);
  final Database _db;
  final ImageStore _images;

  /// Returns the number of photos removed. [days] <= 0 disables purging.
  Future<int> purge({required int days, DateTime? now}) async {
    if (days <= 0) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days)).toUtc().toIso8601String();
    final rows = await _db.query(
      'event_occurrences',
      columns: ['id', 'business_card_path', 'selfie_path'],
      where: 'captured_at < ? AND (business_card_path IS NOT NULL OR selfie_path IS NOT NULL)',
      whereArgs: [cutoff],
    );
    var removed = 0;
    for (final r in rows) {
      for (final col in ['business_card_path', 'selfie_path']) {
        final path = r[col] as String?;
        if (path == null) continue;
        await _images.delete(path);
        await _db.update('contacts', {'photo_path': null}, where: 'photo_path = ?', whereArgs: [path]);
        removed++;
      }
      await _db.update(
        'event_occurrences',
        {'business_card_path': null, 'selfie_path': null},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    if (removed > 0) {
      await AuditLog.write(_db, 'retention.purged', null, {'photos': removed, 'days': days});
    }
    return removed;
  }
}
