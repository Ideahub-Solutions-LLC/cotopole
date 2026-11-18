import '../models/models.dart';

/// Parses contact payloads commonly encoded in business-card QR codes:
/// vCard 2.1/3.0/4.0 and MECARD. Pure Dart — fully unit tested.
abstract final class VCardParser {
  static bool looksLikeContact(String raw) {
    final t = raw.trimLeft().toUpperCase();
    return t.startsWith('BEGIN:VCARD') || t.startsWith('MECARD:');
  }

  /// Returns `null` when [raw] is not a recognisable contact payload.
  static ContactDraft? parse(String raw) {
    final t = raw.trim();
    final upper = t.toUpperCase();
    if (upper.startsWith('BEGIN:VCARD')) return _vcard(t);
    if (upper.startsWith('MECARD:')) return _mecard(t);
    return null;
  }

  static ContactDraft _vcard(String raw) {
    // Unfold continuation lines (RFC 6350 §3.2).
    final unfolded = raw.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));

    var first = '', last = '', fullName = '';
    var org = '', title = '', url = '', adr = '';
    final phones = <(String type, String value)>[];
    final emails = <String>[];

    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final head = line.substring(0, idx);
      final value = line.substring(idx + 1).trim();
      final parts = head.split(';');
      // Strip group prefixes such as "item1.TEL".
      final name = parts.first.split('.').last.toUpperCase();
      final params = parts.skip(1).join(';').toUpperCase();

      switch (name) {
        case 'N':
          final c = _splitEscaped(value, ';');
          last = c.isNotEmpty ? _unescape(c[0]) : '';
          first = c.length > 1 ? _unescape(c[1]) : '';
          final middle = c.length > 2 ? _unescape(c[2]) : '';
          if (middle.isNotEmpty) first = '$first $middle'.trim();
        case 'FN':
          fullName = _unescape(value);
        case 'ORG':
          org = _unescape(_splitEscaped(value, ';').first);
        case 'TITLE':
          title = _unescape(value);
        case 'TEL':
          phones.add((params, _unescape(value).replaceFirst(RegExp(r'^tel:', caseSensitive: false), '')));
        case 'EMAIL':
          emails.add(_unescape(value).replaceFirst(RegExp(r'^mailto:', caseSensitive: false), ''));
        case 'URL':
          if (url.isEmpty) url = _unescape(value);
        case 'ADR':
          if (adr.isEmpty) {
            adr = _splitEscaped(value, ';')
                .map(_unescape)
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .join(', ');
          }
      }
    }

    if (first.isEmpty && last.isEmpty && fullName.isNotEmpty) {
      final split = splitName(fullName);
      first = split.$1;
      last = split.$2;
    }

    return ContactDraft(
      firstName: first,
      lastName: last,
      phone: _preferredPhone(phones),
      email: emails.isNotEmpty ? emails.first : '',
      company: org,
      position: title,
      website: url,
      address: adr,
    );
  }

  static String _preferredPhone(List<(String, String)> phones) {
    if (phones.isEmpty) return '';
    for (final key in ['CELL', 'MOBILE', 'WORK', 'VOICE']) {
      for (final (type, v) in phones) {
        if (type.contains(key) && !type.contains('FAX')) return v;
      }
    }
    for (final (type, v) in phones) {
      if (!type.contains('FAX')) return v;
    }
    return phones.first.$2;
  }

  static ContactDraft _mecard(String raw) {
    final body = raw.substring('MECARD:'.length);
    var first = '', last = '', org = '', title = '', url = '', adr = '', phone = '', email = '';
    for (final field in _splitEscaped(body, ';')) {
      final idx = field.indexOf(':');
      if (idx <= 0) continue;
      final key = field.substring(0, idx).toUpperCase();
      final value = _unescape(field.substring(idx + 1)).trim();
      switch (key) {
        case 'N':
          final c = value.split(',');
          last = c.first.trim();
          first = c.length > 1 ? c[1].trim() : '';
          if (first.isEmpty && !value.contains(',')) {
            final s = splitName(value);
            first = s.$1;
            last = s.$2;
          }
        case 'TEL':
          if (phone.isEmpty) phone = value;
        case 'EMAIL':
          if (email.isEmpty) email = value;
        case 'ORG':
          org = value;
        case 'TITLE':
          title = value;
        case 'URL':
          url = value;
        case 'ADR':
          adr = value.replaceAll(',', ', ').replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    return ContactDraft(
      firstName: first,
      lastName: last,
      phone: phone,
      email: email,
      company: org,
      position: title,
      website: url,
      address: adr,
    );
  }

  /// "Dr. Jane Q. Public" → ("Jane Q.", "Public").
  static (String, String) splitName(String full) {
    final words = full
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => !RegExp(r'^(mr|mrs|ms|dr|prof|engr|atty)\.?$', caseSensitive: false).hasMatch(w))
        .toList();
    if (words.isEmpty) return ('', '');
    if (words.length == 1) return (words.first, '');
    return (words.sublist(0, words.length - 1).join(' '), words.last);
  }

  static List<String> _splitEscaped(String s, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == r'\' && i + 1 < s.length) {
        buf
          ..write(ch)
          ..write(s[i + 1]);
        i++;
      } else if (ch == sep) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  static String _unescape(String s) => s
      .replaceAll(r'\n', ' ')
      .replaceAll(r'\N', ' ')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\:', ':')
      .replaceAll(r'\\', r'\')
      .trim();
}
