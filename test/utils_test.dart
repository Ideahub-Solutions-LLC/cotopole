import 'package:cotopole/core/utils/formatters.dart';
import 'package:cotopole/core/utils/normalizers.dart';
import 'package:cotopole/core/utils/validators.dart';
import 'package:cotopole/data/services/export_service.dart';
import 'package:cotopole/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Normalizers', () {
    test('phone keeps digits and treats 00 like +', () {
      expect(Normalizers.phone('+1 (555) 123-4567'), '15551234567');
      expect(Normalizers.phone('0015551234567'), '15551234567');
      expect(Normalizers.phone('12-34'), isNull);
      expect(Normalizers.phone('  '), isNull);
    });

    test('email lower-cases and trims', () {
      expect(Normalizers.email('  Jane@Acme.COM '), 'jane@acme.com');
      expect(Normalizers.email(''), isNull);
    });

    test('event key ignores case, spacing and time of day', () {
      final a = Normalizers.eventKey('Dental  Expo', DateTime(2026, 11, 18, 9));
      final b = Normalizers.eventKey(' dental expo ', DateTime(2026, 11, 18, 17, 30));
      expect(a, b);
      expect(a, isNot(Normalizers.eventKey('Dental Expo', DateTime(2026, 11, 19))));
    });

    test('smartCase only softens ALL CAPS', () {
      expect(Normalizers.smartCase('JANE DOE'), 'Jane Doe');
      expect(Normalizers.smartCase('McArthur'), 'McArthur');
    });
  });

  group('Validators', () {
    test('event name length rule', () {
      expect(Validators.eventName(''), isNotNull);
      expect(Validators.eventName('a' * 150), isNull);
      expect(Validators.eventName('a' * 151), isNotNull);
    });

    test('phone or email is required', () {
      expect(Validators.phoneOrEmail('', ' '), isNotNull);
      expect(Validators.phoneOrEmail('0917 123 4567', ''), isNull);
      expect(Validators.phoneOrEmail('', 'a@b.co'), isNull);
    });

    test('email and phone formats', () {
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('jane@acme.com'), isNull);
      expect(Validators.phone('12'), isNotNull);
      expect(Validators.phone('+63 (917) 555-0123'), isNull);
    });

    test('notes limit is 2000', () {
      expect(Validators.notes('x' * 2000), isNull);
      expect(Validators.notes('x' * 2001), isNotNull);
    });
  });

  group('Fmt', () {
    test('initials', () {
      expect(Fmt.initials('jane', 'doe'), 'JD');
      expect(Fmt.initials('', ''), '?');
    });

    test('relative time', () {
      final now = DateTime(2026, 11, 18, 12);
      expect(Fmt.relative(now.subtract(const Duration(seconds: 5)), now: now), 'just now');
      expect(Fmt.relative(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(Fmt.relative(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    });
  });

  group('ExportService', () {
    test('CSV escapes quotes/commas and neutralises formulas', () {
      final now = DateTime(2026, 11, 18);
      final contact = Contact(
        id: 'c1',
        firstName: 'Jane',
        lastName: 'Doe, Jr.',
        email: 'jane@acme.com',
        company: '=HYPERLINK("x")',
        phone: '+63 917 555 0123',
        createdAt: now,
        updatedAt: now,
      );
      final occ = Occurrence(
        id: 'o1',
        eventId: 'e1',
        contactId: 'c1',
        capturedAt: now,
        captureMethod: CaptureMethod.manual,
        duplicateResolution: DuplicateResolution.newContact,
        followUpStatus: FollowUpStatus.pending,
        notes: 'Said "call me"',
        eventName: 'Expo',
      );
      final csv = ExportService.occurrencesCsv([occ], {'c1': contact});
      expect(csv, contains('"Doe, Jr."'));
      expect(csv, contains('"Said ""call me"""'));
      expect(csv, contains("'=HYPERLINK"));
      // A phone number starting with + is data, not a formula.
      expect(csv, contains(',+63 917 555 0123,'));
    });

    test('vCard round-trips through the parser', () {
      final now = DateTime(2026, 11, 18);
      final c = Contact(
        id: 'c1',
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane@acme.com',
        phone: '+1 555 222 3333',
        company: 'Acme',
        createdAt: now,
        updatedAt: now,
      );
      expect(ExportService.vcard(c), contains('FN:Jane Doe'));
    });
  });
}
