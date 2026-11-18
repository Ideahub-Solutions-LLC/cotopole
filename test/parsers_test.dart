import 'package:cotopole/data/services/card_text_parser.dart';
import 'package:cotopole/data/services/vcard_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VCardParser', () {
    test('parses vCard 3.0 and prefers the mobile number', () {
      const raw = 'BEGIN:VCARD\r\n'
          'VERSION:3.0\r\n'
          'N:Doe;Jane;;;\r\n'
          'FN:Jane Doe\r\n'
          'ORG:Acme Corp;Sales\r\n'
          'TITLE:VP Sales\r\n'
          'TEL;TYPE=WORK,VOICE:+1 555 000 1111\r\n'
          'TEL;TYPE=CELL:+1 555 222 3333\r\n'
          'EMAIL;TYPE=INTERNET:jane@acme.com\r\n'
          'URL:https://acme.com\r\n'
          'ADR;TYPE=WORK:;;1 Main St;Springfield;IL;62701;USA\r\n'
          'END:VCARD';
      final d = VCardParser.parse(raw)!;
      expect(d.firstName, 'Jane');
      expect(d.lastName, 'Doe');
      expect(d.company, 'Acme Corp');
      expect(d.position, 'VP Sales');
      expect(d.phone, '+1 555 222 3333');
      expect(d.email, 'jane@acme.com');
      expect(d.website, 'https://acme.com');
      expect(d.address, '1 Main St, Springfield, IL, 62701, USA');
    });

    test('falls back to FN when N is missing and unfolds long lines', () {
      const raw = 'BEGIN:VCARD\nVERSION:4.0\nFN:Dr. Maria\n  Clara Santos\nEMAIL:maria@x.ph\nEND:VCARD';
      final d = VCardParser.parse(raw)!;
      expect(d.firstName, 'Maria Clara');
      expect(d.lastName, 'Santos');
      expect(d.email, 'maria@x.ph');
    });

    test('parses MECARD', () {
      final d = VCardParser.parse('MECARD:N:Doe,John;TEL:+15551234567;EMAIL:john@example.com;ORG:Example Inc;;')!;
      expect(d.firstName, 'John');
      expect(d.lastName, 'Doe');
      expect(d.phone, '+15551234567');
      expect(d.email, 'john@example.com');
      expect(d.company, 'Example Inc');
    });

    test('rejects non-contact payloads', () {
      expect(VCardParser.parse('https://example.com'), isNull);
      expect(VCardParser.looksLikeContact('WIFI:S:guest;;'), isFalse);
    });

    test('splitName strips honorifics', () {
      expect(VCardParser.splitName('Engr. Juan Dela Cruz'), ('Juan Dela', 'Cruz'));
      expect(VCardParser.splitName('Cher'), ('Cher', ''));
    });
  });

  group('CardTextParser', () {
    test('extracts every field from a typical business card', () {
      final r = CardTextParser.parse(const [
        OcrLine('JANE DOE', height: 40, top: 10),
        OcrLine('Head of Operations', height: 18, top: 60),
        OcrLine('Acme Dental Solutions Inc.', height: 20, top: 90),
        OcrLine('M: +63 917 555 0123', height: 14, top: 140),
        OcrLine('F: +63 2 8555 0000', height: 14, top: 160),
        OcrLine('jane.doe@acmedental.com', height: 14, top: 180),
        OcrLine('www.acmedental.com', height: 14, top: 200),
        OcrLine('12F Tower One, Ayala Avenue, Makati 1226', height: 14, top: 220),
      ]);
      final d = r.draft;
      expect(d.firstName, 'Jane');
      expect(d.lastName, 'Doe');
      expect(d.position, 'Head of Operations');
      expect(d.company, 'Acme Dental Solutions Inc.');
      expect(d.phone, '+63 917 555 0123');
      expect(d.email, 'jane.doe@acmedental.com');
      expect(d.website, 'www.acmedental.com');
      expect(d.address, contains('Ayala Avenue'));
      expect(r.uncertain, isEmpty);
    });

    test('prefers a labelled mobile over an office line and skips fax', () {
      final r = CardTextParser.parse(const [
        OcrLine('Carlos Reyes', height: 30),
        OcrLine('Fax: (02) 8999 1111', height: 12),
        OcrLine('T: (02) 8123 4567', height: 12),
        OcrLine('Mobile 0917 123 4567', height: 12),
        OcrLine('carlos@reyesbuilders.ph', height: 12),
      ]);
      expect(r.draft.phone, '0917 123 4567');
      expect(r.draft.firstName, 'Carlos');
      expect(r.draft.lastName, 'Reyes');
    });

    test('derives the company from a business email domain and flags it', () {
      final r = CardTextParser.parse(const [
        OcrLine('John Smith', height: 30),
        OcrLine('john@globex.com', height: 12),
      ]);
      expect(r.draft.company, 'Globex');
      expect(r.uncertain, contains('company'));
    });

    test('does not derive a company from free-mail domains', () {
      final r = CardTextParser.parse(const [
        OcrLine('Ana Lim', height: 30),
        OcrLine('ana.lim@gmail.com', height: 12),
      ]);
      expect(r.draft.company, isEmpty);
    });

    test('flags missing contact channels', () {
      final r = CardTextParser.parse(const [OcrLine('Just A Name', height: 20)]);
      expect(r.uncertain, containsAll(['phone', 'email']));
    });
  });
}
