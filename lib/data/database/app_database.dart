import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database — the only data store for the app. There is no
/// remote database; everything lives on the device.
///
/// Schema is versioned with `PRAGMA user_version` (via sqflite's `version`)
/// so later releases can add migrations in [_onUpgrade] without data loss.
class AppDatabase {
  AppDatabase._();

  static const fileName = 'cotopole.db';
  static const schemaVersion = 1;

  /// Opens (and creates/migrates) the database.
  ///
  /// [factory] and [path] are injectable so tests can use an in-memory
  /// sqflite_common_ffi database.
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createV1(db);
        },
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here, e.g.:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        email TEXT,
        title TEXT,
        role TEXT NOT NULL CHECK (role IN ('admin','staff')),
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_key TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        location TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
        owner_profile_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_events_name_key ON events(name_key)');
    batch.execute('CREATE INDEX idx_events_starts_at ON events(starts_at)');

    // Contacts are global, not event-scoped. The join to an event is always
    // through event_occurrences. Normalized columns are indexed but NOT
    // unique: an ambiguous multi-match is a valid held state.
    batch.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT,
        phone_normalized TEXT,
        email TEXT,
        email_normalized TEXT,
        company TEXT,
        position TEXT,
        website TEXT,
        address TEXT,
        photo_path TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_by_profile_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_contacts_phone_norm ON contacts(phone_normalized)');
    batch.execute('CREATE INDEX idx_contacts_email_norm ON contacts(email_normalized)');
    batch.execute('CREATE INDEX idx_contacts_name ON contacts(last_name, first_name)');

    batch.execute('''
      CREATE TABLE event_occurrences (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        contact_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
        captured_at TEXT NOT NULL,
        capture_method TEXT NOT NULL
          CHECK (capture_method IN ('manual','image','qr','mixed')),
        duplicate_resolution TEXT NOT NULL
          CHECK (duplicate_resolution IN ('new','phone_match','email_match','admin_resolved')),
        notes TEXT CHECK (notes IS NULL OR length(notes) <= 2000),
        rating TEXT CHECK (rating IS NULL OR rating IN ('hot','warm','cold')),
        follow_up_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (follow_up_status IN ('pending','contacted','done')),
        business_card_path TEXT,
        selfie_path TEXT,
        ocr_raw_text TEXT,
        captured_by_profile_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_occ_event ON event_occurrences(event_id)');
    batch.execute('CREATE INDEX idx_occ_contact ON event_occurrences(contact_id)');
    batch.execute('CREATE INDEX idx_occ_captured_at ON event_occurrences(captured_at)');

    batch.execute('''
      CREATE TABLE audit_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        actor_profile_id TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_audit_created ON audit_events(created_at)');

    await batch.commit(noResult: true);
  }
}
