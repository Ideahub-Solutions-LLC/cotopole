/// Enumerations mirroring the Cotople pilot-domain schema.
library;

enum UserRole {
  admin('admin', 'Organiser'),
  staff('staff', 'Event Staff');

  const UserRole(this.db, this.label);
  final String db;
  final String label;

  static UserRole fromDb(String? v) =>
      UserRole.values.firstWhere((e) => e.db == v, orElse: () => UserRole.staff);
}

enum EventStatus {
  active('active'),
  archived('archived');

  const EventStatus(this.db);
  final String db;

  static EventStatus fromDb(String? v) =>
      EventStatus.values.firstWhere((e) => e.db == v, orElse: () => EventStatus.active);
}

enum CaptureMethod {
  manual('manual', 'Manual'),
  image('image', 'Card scan'),
  qr('qr', 'QR / vCard'),
  mixed('mixed', 'Mixed');

  const CaptureMethod(this.db, this.label);
  final String db;
  final String label;

  static CaptureMethod fromDb(String? v) =>
      CaptureMethod.values.firstWhere((e) => e.db == v, orElse: () => CaptureMethod.manual);
}

enum DuplicateResolution {
  newContact('new', 'New contact'),
  phoneMatch('phone_match', 'Phone match'),
  emailMatch('email_match', 'Email match'),
  adminResolved('admin_resolved', 'Organiser resolved');

  const DuplicateResolution(this.db, this.label);
  final String db;
  final String label;

  static DuplicateResolution fromDb(String? v) => DuplicateResolution.values
      .firstWhere((e) => e.db == v, orElse: () => DuplicateResolution.newContact);
}

/// Lead temperature recorded per meeting — helps whoever does follow-up
/// prioritise. Stored on the occurrence, not the person.
enum LeadRating {
  hot('hot', 'Hot'),
  warm('warm', 'Warm'),
  cold('cold', 'Cold');

  const LeadRating(this.db, this.label);
  final String db;
  final String label;

  static LeadRating? fromDb(String? v) {
    for (final r in LeadRating.values) {
      if (r.db == v) return r;
    }
    return null;
  }
}

/// Local follow-up tracking per occurrence (SOP-004 §6 interim process).
enum FollowUpStatus {
  pending('pending', 'To follow up'),
  contacted('contacted', 'Contacted'),
  done('done', 'Done');

  const FollowUpStatus(this.db, this.label);
  final String db;
  final String label;

  static FollowUpStatus fromDb(String? v) =>
      FollowUpStatus.values.firstWhere((e) => e.db == v, orElse: () => FollowUpStatus.pending);
}
