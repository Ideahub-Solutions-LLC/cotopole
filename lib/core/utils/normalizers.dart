/// Normalisation used for duplicate detection.
///
/// Mirrors the backend contract in the Cotople system documentation:
/// contacts are de-duplicated by normalized phone first, then normalized
/// email. Both indexes are intentionally NOT unique — an ambiguous
/// multi-match is a valid, held state.
abstract final class Normalizers {
  /// Keeps digits only, and a leading `+` if present. Returns `null` when
  /// fewer than 6 digits remain (too short to be a usable match key).
  static String? phone(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null;
    // Treat a leading international "00" the same as "+".
    if (digits.startsWith('00')) return digits.substring(2);
    return digits;
  }

  /// Lower-cased, trimmed email. Returns `null` for blank input.
  static String? email(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    return v.isEmpty ? null : v;
  }

  /// Case-insensitive, whitespace-collapsed event name.
  static String eventNameKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Key used to de-duplicate events: normalized name plus calendar date
  /// (time of day ignored), per EVT-0005.
  static String eventKey(String name, DateTime startsAt) {
    final n = eventNameKey(name);
    final d = '${startsAt.year.toString().padLeft(4, '0')}-'
        '${startsAt.month.toString().padLeft(2, '0')}-'
        '${startsAt.day.toString().padLeft(2, '0')}';
    return '$n|$d';
  }

  /// Title-cases a name fragment that was captured in ALL CAPS by OCR.
  static String smartCase(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    final isAllCaps = s == s.toUpperCase() && s != s.toLowerCase();
    if (!isAllCaps) return s;
    return s
        .toLowerCase()
        .split(RegExp(r'(\s+)'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
