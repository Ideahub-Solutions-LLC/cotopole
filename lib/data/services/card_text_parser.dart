import '../../core/utils/normalizers.dart';
import '../models/models.dart';
import 'vcard_parser.dart';

/// A single line of recognised text with its on-card geometry.
class OcrLine {
  const OcrLine(this.text, {this.height = 0, this.top = 0});
  final String text;

  /// Bounding-box height in pixels — larger text is usually the name.
  final double height;

  /// Vertical position — used as a tie-breaker (names sit near the top).
  final double top;
}

class ParsedCard {
  const ParsedCard(this.draft, {this.uncertain = const {}});
  final ContactDraft draft;

  /// Field keys the heuristics were unsure about; the review screen
  /// highlights these so staff check them before saving (GAP COR-04).
  final Set<String> uncertain;
}

/// Turns raw OCR lines from a business card into contact fields.
///
/// Pure Dart heuristics so they are fast, offline and unit-testable:
/// regexes for email/phone/web, keyword lists for job titles and company
/// suffixes, and a font-size-weighted score for the person's name.
abstract final class CardTextParser {
  static final _emailRe = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final _webRe = RegExp(
    r'((https?://)?(www\.)[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+(/\S*)?)|(https?://[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+(/\S*)?)|(\b[A-Za-z0-9\-]+\.(com|net|org|io|co|ph|ai|biz|info|us|uk|ca|au|sg|app|dev|tech)(\.[a-z]{2})?\b(/\S*)?)',
    caseSensitive: false,
  );
  static final _phoneRe = RegExp(r'(\+?\(?\d[\d\s().\-/]{6,}\d)');
  static final _faxLabel = RegExp(r'\b(fax|f\s*[:.])', caseSensitive: false);
  static final _mobileLabel = RegExp(r'\b(mobile|mob|cell|m\s*[:.]|cp)', caseSensitive: false);
  static final _labelPrefix = RegExp(
    r'^\s*(tel|telephone|phone|ph|mobile|mob|cell|cp|direct|office|landline|t|m|p|d|o|e|w|email|e-mail|web|website)\s*[:.]?\s*',
    caseSensitive: false,
  );

  static const _titleWords = [
    'ceo', 'cto', 'cfo', 'coo', 'cmo', 'cio', 'founder', 'co-founder', 'cofounder', 'owner',
    'president', 'vice president', 'vp', 'director', 'manager', 'head', 'lead', 'chief',
    'officer', 'engineer', 'developer', 'designer', 'consultant', 'specialist', 'analyst',
    'executive', 'coordinator', 'associate', 'partner', 'principal', 'architect', 'advisor',
    'adviser', 'representative', 'sales', 'marketing', 'supervisor', 'administrator',
    'assistant', 'secretary', 'treasurer', 'chairman', 'chairperson', 'agent', 'broker',
    'strategist', 'producer', 'editor', 'scientist', 'researcher', 'professor', 'attorney',
    'lawyer', 'accountant', 'doctor', 'nurse', 'intern', 'business development',
  ];

  static const _companyWords = [
    'inc', 'inc.', 'llc', 'l.l.c', 'ltd', 'ltd.', 'limited', 'corp', 'corp.', 'corporation',
    'co.', 'company', 'gmbh', 'plc', 'pty', 'pte', 'sa', 'ag', 'bv', 'group', 'holdings',
    'solutions', 'technologies', 'technology', 'systems', 'labs', 'studio', 'studios',
    'agency', 'partners', 'associates', 'consulting', 'enterprises', 'industries',
    'international', 'global', 'ventures', 'capital', 'media', 'foundation', 'university',
    'institute', 'bank', 'hospital', 'clinic', 'services', 'software', 'digital', 'network',
  ];

  static const _addressWords = [
    'street', 'st.', 'st,', 'avenue', 'ave', 'road', 'rd', 'blvd', 'boulevard', 'suite',
    'ste', 'floor', 'flr', 'bldg', 'building', 'tower', 'lane', 'ln', 'drive', 'dr.', 'way',
    'plaza', 'city', 'unit', 'room', 'p.o.', 'po box', 'highway', 'hwy', 'parkway', 'pkwy',
    'court', 'ct', 'brgy', 'barangay', 'district', 'village', 'province', 'state',
  ];

  static const _freeMailDomains = [
    'gmail', 'yahoo', 'hotmail', 'outlook', 'icloud', 'aol', 'proton', 'protonmail', 'live',
    'msn', 'ymail', 'me', 'mail', 'zoho', 'gmx',
  ];

  static ParsedCard parse(List<OcrLine> input) {
    final lines = input
        .map((l) => OcrLine(l.text.replaceAll(RegExp(r'\s+'), ' ').trim(), height: l.height, top: l.top))
        .where((l) => l.text.isNotEmpty)
        .toList();
    final used = <int>{};
    final uncertain = <String>{};

    // ---- email
    var email = '';
    for (var i = 0; i < lines.length; i++) {
      final m = _emailRe.firstMatch(lines[i].text);
      if (m != null) {
        email = m.group(0)!;
        if (_isOnly(lines[i].text, m.group(0)!)) used.add(i);
        break;
      }
    }

    // ---- phone (prefer mobile, skip fax)
    var phone = '';
    var phoneLine = -1;
    for (final preferMobile in [true, false]) {
      for (var i = 0; i < lines.length && phone.isEmpty; i++) {
        final t = lines[i].text;
        if (_faxLabel.hasMatch(t) && !_mobileLabel.hasMatch(t)) continue;
        if (preferMobile && !_mobileLabel.hasMatch(t)) continue;
        if (_emailRe.hasMatch(t)) continue;
        for (final m in _phoneRe.allMatches(t)) {
          final candidate = m.group(0)!.trim();
          final digits = candidate.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 7 && digits.length <= 15 && !_looksLikeDate(candidate)) {
            phone = candidate;
            phoneLine = i;
            break;
          }
        }
      }
      if (phone.isNotEmpty) break;
    }
    if (phoneLine >= 0) {
      final rest = lines[phoneLine].text.replaceFirst(phone, '').replaceAll(_labelPrefix, '').trim();
      if (rest.replaceAll(RegExp(r'[^A-Za-z]'), '').length < 4) used.add(phoneLine);
    }

    // ---- website
    var website = '';
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].text.replaceAll(_emailRe, ' ');
      final m = _webRe.firstMatch(t);
      if (m != null) {
        website = m.group(0)!.trim();
        if (_isOnly(lines[i].text.replaceAll(_labelPrefix, ''), m.group(0)!)) used.add(i);
        break;
      }
    }

    // Mark lines that are pure contact-channel lines as used.
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].text;
      final stripped = t
          .replaceAll(_emailRe, '')
          .replaceAll(_phoneRe, '')
          .replaceAll(_webRe, '')
          .replaceAll(_labelPrefix, '')
          .replaceAll(RegExp(r'[|•·,;:/]'), '')
          .trim();
      if (stripped.length <= 3 && t.length > 3) used.add(i);
    }

    // ---- position
    var position = '';
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      final lower = ' ${lines[i].text.toLowerCase()} ';
      if (_hasDigit(lines[i].text)) continue;
      if (_titleWords.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(lower))) {
        if (_isCompanyLine(lines[i].text) && !lower.contains('manager')) continue;
        position = lines[i].text;
        used.add(i);
        break;
      }
    }

    // ---- company
    var company = '';
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      if (_isCompanyLine(lines[i].text)) {
        company = lines[i].text;
        used.add(i);
        break;
      }
    }

    // ---- address (one or two consecutive lines)
    var address = '';
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      if (_isAddressLine(lines[i].text)) {
        address = lines[i].text;
        used.add(i);
        if (i + 1 < lines.length && !used.contains(i + 1) && _looksLikeAddressTail(lines[i + 1].text)) {
          address = '$address, ${lines[i + 1].text}';
          used.add(i + 1);
        }
        break;
      }
    }

    // ---- name: highest-scoring remaining line
    final emailLocal = email.split('@').first.toLowerCase();
    var bestScore = double.negativeInfinity;
    var bestIdx = -1;
    final maxHeight = lines.fold<double>(0, (m, l) => l.height > m ? l.height : m);
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      final score = _nameScore(lines[i], i, lines.length, maxHeight, emailLocal);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    var first = '', last = '';
    if (bestIdx >= 0 && bestScore > 0) {
      final (f, l) = VCardParser.splitName(Normalizers.smartCase(lines[bestIdx].text));
      first = f;
      last = l;
      used.add(bestIdx);
      if (bestScore < 3) uncertain.add('name');
    } else {
      uncertain.add('name');
    }

    // Company fallback: business email domain.
    if (company.isEmpty && email.contains('@')) {
      final domain = email.split('@').last.split('.').first.toLowerCase();
      if (!_freeMailDomains.contains(domain) && domain.length > 1) {
        company = domain[0].toUpperCase() + domain.substring(1);
        uncertain.add('company');
      }
    }

    if (company.isNotEmpty && company == company.toUpperCase() && company.length > 4) {
      // Keep acronyms (IBM) but soften shouted names (ACME TRADING).
      if (company.contains(' ')) company = Normalizers.smartCase(company);
    }
    if (position.isNotEmpty) position = Normalizers.smartCase(position);
    if (phone.isEmpty && email.isEmpty) {
      uncertain.addAll(['phone', 'email']);
    }

    return ParsedCard(
      ContactDraft(
        firstName: first,
        lastName: last,
        phone: phone,
        email: email,
        company: company,
        position: position,
        website: website,
        address: address,
      ),
      uncertain: uncertain,
    );
  }

  static double _nameScore(OcrLine line, int index, int total, double maxHeight, String emailLocal) {
    final t = line.text;
    if (_hasDigit(t) || t.contains('@') || t.contains('www') || t.contains('http')) return -10;
    final words = t.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.length > 4) return -5;
    if (t.length > 40 || t.length < 3) return -5;
    if (!words.every((w) => RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ'.\-]*$").hasMatch(w))) return -4;
    if (_isCompanyLine(t)) return -3;

    var score = 1.0;
    if (words.length >= 2 && words.length <= 3) score += 2;
    if (words.every((w) => w[0] == w[0].toUpperCase())) score += 1;
    if (maxHeight > 0 && line.height > 0) score += 3 * (line.height / maxHeight);
    score += 1.0 * (1 - index / (total == 0 ? 1 : total)); // nearer the top
    if (emailLocal.isNotEmpty) {
      final lw = words.map((w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));
      if (lw.any((w) => w.length > 2 && emailLocal.contains(w))) score += 3;
      if (lw.any((w) => w.isNotEmpty && emailLocal.startsWith(w[0])) && emailLocal.length <= 3) score += 0.5;
    }
    return score;
  }

  static bool _isCompanyLine(String t) {
    final lower = ' ${t.toLowerCase().replaceAll(',', ' ')} ';
    return _companyWords.any((w) => lower.contains(' $w ') || lower.endsWith(' $w'));
  }

  static bool _isAddressLine(String t) {
    final lower = ' ${t.toLowerCase()} ';
    final hasKeyword = _addressWords.any((w) => lower.contains(' $w'));
    final hasNumber = RegExp(r'\d').hasMatch(t);
    final hasPostal = RegExp(r'\b\d{4,6}\b').hasMatch(t) && t.contains(',');
    return (hasKeyword && hasNumber) || hasPostal;
  }

  static bool _looksLikeAddressTail(String t) =>
      t.contains(',') &&
      !_emailRe.hasMatch(t) &&
      !_webRe.hasMatch(t) &&
      t.replaceAll(RegExp(r'\D'), '').length < 7;

  static bool _hasDigit(String t) => RegExp(r'\d').hasMatch(t);

  static bool _looksLikeDate(String t) => RegExp(r'^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$').hasMatch(t.trim());

  static bool _isOnly(String line, String match) {
    final rest = line.replaceFirst(match, '').replaceAll(_labelPrefix, '').trim();
    return rest.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length <= 2;
  }
}
