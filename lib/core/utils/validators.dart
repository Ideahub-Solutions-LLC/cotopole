/// Field rules taken from SOP-004 §5.1 and §5.2.
abstract final class Validators {
  static const eventNameMax = 150;
  static const locationMax = 255;
  static const notesMax = 2000;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? eventName(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Event name is required';
    if (t.length > eventNameMax) return 'Keep it under $eventNameMax characters';
    return null;
  }

  static String? location(String? v) {
    if ((v?.trim().length ?? 0) > locationMax) return 'Keep it under $locationMax characters';
    return null;
  }

  static String? notes(String? v) {
    if ((v?.length ?? 0) > notesMax) return 'Keep it under $notesMax characters';
    return null;
  }

  static String? email(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return _email.hasMatch(t) ? null : 'Enter a valid email';
  }

  static String? phone(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return 'Enter a valid phone number';
    if (!RegExp(r'^[+\d\s().\-/x]+$').hasMatch(t)) return 'Only digits and + ( ) - are allowed';
    return null;
  }

  /// Duplicate detection runs on phone then email, so at least one is needed.
  static String? phoneOrEmail(String? phone, String? email) {
    final p = phone?.trim() ?? '';
    final e = email?.trim() ?? '';
    if (p.isEmpty && e.isEmpty) return 'Add a phone number or an email';
    return null;
  }

  static String? pin(String? v, {int length = 6}) {
    final t = v ?? '';
    if (t.length != length || int.tryParse(t) == null) return 'PIN must be $length digits';
    return null;
  }
}
