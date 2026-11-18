import 'package:sqflite/sqflite.dart';

/// Key/value app settings stored in SQLite.
class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  static const kCurrentEventId = 'current_event_id';
  static const kLastProfileId = 'last_profile_id';
  static const kRetentionDays = 'image_retention_days';
  static const kAutoLockMinutes = 'auto_lock_minutes';
  static const kOnboarded = 'onboarded';

  static const defaultRetentionDays = 30;
  static const defaultAutoLockMinutes = 5;

  Future<String?> get(String key) async {
    final rows = await _db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String? value) async {
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, int fallback) async =>
      int.tryParse(await get(key) ?? '') ?? fallback;

  Future<int> retentionDays() => getInt(kRetentionDays, defaultRetentionDays);
  Future<int> autoLockMinutes() => getInt(kAutoLockMinutes, defaultAutoLockMinutes);
}
