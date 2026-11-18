import 'enums.dart';

export 'enums.dart';

DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dtOrNull(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
String _iso(DateTime d) => d.toUtc().toIso8601String();

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
    required this.createdAt,
    this.email,
    this.title,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? title;
  final UserRole role;
  final String pinHash;
  final String pinSalt;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory Profile.fromRow(Map<String, Object?> r) => Profile(
        id: r['id'] as String,
        displayName: r['display_name'] as String,
        email: r['email'] as String?,
        title: r['title'] as String?,
        role: UserRole.fromDb(r['role'] as String?),
        pinHash: r['pin_hash'] as String,
        pinSalt: r['pin_salt'] as String,
        failedAttempts: (r['failed_attempts'] as int?) ?? 0,
        lockedUntil: _dtOrNull(r['locked_until']),
        createdAt: _dt(r['created_at']),
      );
}

class Event {
  const Event({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.notes,
    this.ownerProfileId,
    this.contactCount = 0,
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final String? location;
  final String? notes;
  final EventStatus status;
  final String? ownerProfileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Number of occurrences captured at this event (aggregated in queries).
  final int contactCount;

  bool get isArchived => status == EventStatus.archived;

  bool get isLive {
    final now = DateTime.now();
    return !isArchived &&
        startsAt.year == now.year &&
        startsAt.month == now.month &&
        startsAt.day == now.day;
  }

  bool get isUpcoming => !isArchived && startsAt.isAfter(DateTime.now()) && !isLive;

  factory Event.fromRow(Map<String, Object?> r) => Event(
        id: r['id'] as String,
        name: r['name'] as String,
        startsAt: _dt(r['starts_at']),
        location: r['location'] as String?,
        notes: r['notes'] as String?,
        status: EventStatus.fromDb(r['status'] as String?),
        ownerProfileId: r['owner_profile_id'] as String?,
        createdAt: _dt(r['created_at']),
        updatedAt: _dt(r['updated_at']),
        contactCount: (r['contact_count'] as int?) ?? 0,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'starts_at': _iso(startsAt),
        'location': location,
        'notes': notes,
        'status': status.db,
        'owner_profile_id': ownerProfileId,
        'created_at': _iso(createdAt),
        'updated_at': _iso(updatedAt),
      };
}

/// Editable contact fields — used by the capture form, the OCR review screen
/// and the edit screen.
class ContactDraft {
  const ContactDraft({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.company = '',
    this.position = '',
    this.website = '',
    this.address = '',
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String company;
  final String position;
  final String website;
  final String address;

  bool get isEmpty =>
      [firstName, lastName, phone, email, company, position, website, address]
          .every((s) => s.trim().isEmpty);

  ContactDraft copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? company,
    String? position,
    String? website,
    String? address,
  }) =>
      ContactDraft(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        company: company ?? this.company,
        position: position ?? this.position,
        website: website ?? this.website,
        address: address ?? this.address,
      );

  /// Fills blanks in `this` with values from [other]; never overwrites.
  ContactDraft mergeMissing(ContactDraft other) {
    String pick(String a, String b) => a.trim().isNotEmpty ? a : b;
    return ContactDraft(
      firstName: pick(firstName, other.firstName),
      lastName: pick(lastName, other.lastName),
      phone: pick(phone, other.phone),
      email: pick(email, other.email),
      company: pick(company, other.company),
      position: pick(position, other.position),
      website: pick(website, other.website),
      address: pick(address, other.address),
    );
  }

  @override
  String toString() => 'ContactDraft($firstName $lastName, $phone, $email, $company, $position)';
}

class Contact {
  const Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.company,
    this.position,
    this.website,
    this.address,
    this.photoPath,
    this.isFavorite = false,
    this.createdByProfileId,
    this.occurrenceCount = 0,
    this.lastSeenAt,
    this.lastEventName,
    this.lastRating,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String? company;
  final String? position;
  final String? website;
  final String? address;
  final String? photoPath;
  final bool isFavorite;
  final String? createdByProfileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Aggregates (populated by list queries)
  final int occurrenceCount;
  final DateTime? lastSeenAt;
  final String? lastEventName;
  final LeadRating? lastRating;

  String get fullName => '$firstName $lastName'.trim();

  String get subtitle {
    final parts = [position, company].where((s) => s != null && s.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' · ');
    return email ?? phone ?? '';
  }

  ContactDraft toDraft() => ContactDraft(
        firstName: firstName,
        lastName: lastName,
        phone: phone ?? '',
        email: email ?? '',
        company: company ?? '',
        position: position ?? '',
        website: website ?? '',
        address: address ?? '',
      );

  factory Contact.fromRow(Map<String, Object?> r) => Contact(
        id: r['id'] as String,
        firstName: r['first_name'] as String,
        lastName: r['last_name'] as String,
        phone: r['phone'] as String?,
        email: r['email'] as String?,
        company: r['company'] as String?,
        position: r['position'] as String?,
        website: r['website'] as String?,
        address: r['address'] as String?,
        photoPath: r['photo_path'] as String?,
        isFavorite: (r['is_favorite'] as int? ?? 0) == 1,
        createdByProfileId: r['created_by_profile_id'] as String?,
        createdAt: _dt(r['created_at']),
        updatedAt: _dt(r['updated_at']),
        occurrenceCount: (r['occurrence_count'] as int?) ?? 0,
        lastSeenAt: _dtOrNull(r['last_seen_at']),
        lastEventName: r['last_event_name'] as String?,
        lastRating: LeadRating.fromDb(r['last_rating'] as String?),
      );
}

/// One row per capture: "we met this person at this event".
class Occurrence {
  const Occurrence({
    required this.id,
    required this.eventId,
    required this.contactId,
    required this.capturedAt,
    required this.captureMethod,
    required this.duplicateResolution,
    required this.followUpStatus,
    this.notes,
    this.rating,
    this.businessCardPath,
    this.selfiePath,
    this.capturedByProfileId,
    this.eventName,
    this.contactName,
    this.contactCompany,
    this.contactPhotoPath,
    this.capturedByName,
  });

  final String id;
  final String eventId;
  final String contactId;
  final DateTime capturedAt;
  final CaptureMethod captureMethod;
  final DuplicateResolution duplicateResolution;
  final FollowUpStatus followUpStatus;
  final String? notes;
  final LeadRating? rating;
  final String? businessCardPath;
  final String? selfiePath;
  final String? capturedByProfileId;

  // Joined display fields
  final String? eventName;
  final String? contactName;
  final String? contactCompany;
  final String? contactPhotoPath;
  final String? capturedByName;

  factory Occurrence.fromRow(Map<String, Object?> r) => Occurrence(
        id: r['id'] as String,
        eventId: r['event_id'] as String,
        contactId: r['contact_id'] as String,
        capturedAt: _dt(r['captured_at']),
        captureMethod: CaptureMethod.fromDb(r['capture_method'] as String?),
        duplicateResolution: DuplicateResolution.fromDb(r['duplicate_resolution'] as String?),
        followUpStatus: FollowUpStatus.fromDb(r['follow_up_status'] as String?),
        notes: r['notes'] as String?,
        rating: LeadRating.fromDb(r['rating'] as String?),
        businessCardPath: r['business_card_path'] as String?,
        selfiePath: r['selfie_path'] as String?,
        capturedByProfileId: r['captured_by_profile_id'] as String?,
        eventName: r['event_name'] as String?,
        contactName: r['contact_name'] as String?,
        contactCompany: r['contact_company'] as String?,
        contactPhotoPath: r['contact_photo_path'] as String?,
        capturedByName: r['captured_by_name'] as String?,
      );
}

String isoNow() => DateTime.now().toUtc().toIso8601String();
String toIso(DateTime d) => _iso(d);
