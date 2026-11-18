import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'audit_log.dart';

/// Salted, stretched PIN hashing. The PIN never leaves the device and is
/// never stored in plain text.
abstract final class PinHasher {
  static const _iterations = 20000;

  static String newSalt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  /// Constant-time comparison.
  static bool matches(String pin, String salt, String expectedHash) {
    final a = hash(pin, salt);
    if (a.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}

sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk(this.profile);
  final Profile profile;
}

class PinWrong extends PinCheck {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

class PinLocked extends PinCheck {
  const PinLocked(this.until);
  final DateTime until;
}

class ProfileRepository {
  ProfileRepository(this._db);
  final Database _db;

  /// Lock out after this many consecutive wrong PINs (mitigates GAP SEC-05).
  static const maxAttempts = 5;
  static const lockDuration = Duration(seconds: 60);

  Future<int> count() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM profiles')) ?? 0;

  Future<List<Profile>> list() async {
    final rows = await _db.query('profiles', orderBy: 'role ASC, display_name COLLATE NOCASE');
    return rows.map(Profile.fromRow).toList();
  }

  Future<Profile?> get(String id) async {
    final rows = await _db.query('profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Profile.fromRow(rows.first);
  }

  Future<Profile> create({
    required String displayName,
    required UserRole role,
    required String pin,
    String? email,
    String? title,
    String? actorId,
  }) async {
    final id = const Uuid().v4();
    final salt = PinHasher.newSalt();
    final now = isoNow();
    await _db.insert('profiles', {
      'id': id,
      'display_name': displayName.trim(),
      'email': _blankToNull(email),
      'title': _blankToNull(title),
      'role': role.db,
      'pin_hash': PinHasher.hash(pin, salt),
      'pin_salt': salt,
      'failed_attempts': 0,
      'created_at': now,
      'updated_at': now,
    });
    await AuditLog.write(_db, 'profile.created', actorId ?? id, {'profile_id': id, 'role': role.db});
    return (await get(id))!;
  }

  Future<void> update(Profile p, {String? displayName, String? email, String? title, UserRole? role}) async {
    await _db.update(
      'profiles',
      {
        'display_name': (displayName ?? p.displayName).trim(),
        'email': _blankToNull(email ?? p.email),
        'title': _blankToNull(title ?? p.title),
        'role': (role ?? p.role).db,
        'updated_at': isoNow(),
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<PinCheck> verifyPin(String profileId, String pin, {DateTime? now}) async {
    final p = await get(profileId);
    if (p == null) return const PinWrong(0);
    final t = now ?? DateTime.now();
    if (p.lockedUntil != null && p.lockedUntil!.isAfter(t)) {
      return PinLocked(p.lockedUntil!);
    }
    if (PinHasher.matches(pin, p.pinSalt, p.pinHash)) {
      await _db.update(
        'profiles',
        {'failed_attempts': 0, 'locked_until': null},
        where: 'id = ?',
        whereArgs: [p.id],
      );
      await AuditLog.write(_db, 'auth.unlock', p.id, null);
      return PinOk(p);
    }
    final attempts = p.failedAttempts + 1;
    if (attempts >= maxAttempts) {
      final until = t.add(lockDuration);
      await _db.update(
        'profiles',
        {'failed_attempts': 0, 'locked_until': toIso(until)},
        where: 'id = ?',
        whereArgs: [p.id],
      );
      await AuditLog.write(_db, 'auth.locked', p.id, {'attempts': attempts});
      return PinLocked(until);
    }
    await _db.update('profiles', {'failed_attempts': attempts}, where: 'id = ?', whereArgs: [p.id]);
    return PinWrong(maxAttempts - attempts);
  }

  Future<void> changePin(String profileId, String newPin) async {
    final salt = PinHasher.newSalt();
    await _db.update(
      'profiles',
      {
        'pin_hash': PinHasher.hash(newPin, salt),
        'pin_salt': salt,
        'failed_attempts': 0,
        'locked_until': null,
        'updated_at': isoNow(),
      },
      where: 'id = ?',
      whereArgs: [profileId],
    );
    await AuditLog.write(_db, 'auth.pin_changed', profileId, null);
  }

  /// Removes a team member. The last organiser can never be removed.
  Future<void> delete(String profileId, {required String actorId}) async {
    final p = await get(profileId);
    if (p == null) return;
    if (p.isAdmin) {
      final admins = Sqflite.firstIntValue(
            await _db.rawQuery("SELECT COUNT(*) FROM profiles WHERE role = 'admin'"),
          ) ??
          0;
      if (admins <= 1) {
        throw StateError('At least one organiser must remain on this device.');
      }
    }
    await _db.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
    await AuditLog.write(_db, 'profile.deleted', actorId, {'profile_id': profileId});
  }

  static String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}
