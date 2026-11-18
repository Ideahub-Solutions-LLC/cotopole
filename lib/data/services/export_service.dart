import 'dart:io';

import 'package:flutter/widgets.dart' show Rect;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Hands captured leads to whatever system runs the follow-up (SOP-004 §6:
/// "export the occurrence list ... same day"). Files are generated locally
/// and shared through the OS share sheet — nothing is uploaded by the app.
class ExportService {
  /// RFC 4180 CSV of meetings joined with contact details.
  static String occurrencesCsv(List<Occurrence> occurrences, Map<String, Contact> contacts) {
    const header = [
      'Event',
      'Captured at',
      'First name',
      'Last name',
      'Company',
      'Position',
      'Phone',
      'Email',
      'Website',
      'Address',
      'Capture method',
      'Duplicate resolution',
      'Rating',
      'Follow-up',
      'Notes',
      'Captured by',
    ];
    final b = StringBuffer()..writeln(header.map(_cell).join(','));
    for (final o in occurrences) {
      final c = contacts[o.contactId];
      b.writeln([
        o.eventName ?? '',
        o.capturedAt.toIso8601String(),
        c?.firstName ?? '',
        c?.lastName ?? '',
        c?.company ?? '',
        c?.position ?? '',
        c?.phone ?? '',
        c?.email ?? '',
        c?.website ?? '',
        c?.address ?? '',
        o.captureMethod.db,
        o.duplicateResolution.db,
        o.rating?.db ?? '',
        o.followUpStatus.db,
        o.notes ?? '',
        o.capturedByName ?? '',
      ].map(_cell).join(','));
    }
    return b.toString();
  }

  /// vCard 3.0 for saving a lead into the phone's address book.
  static String vcard(Contact c) {
    String esc(String? s) =>
        (s ?? '').replaceAll(r'\', r'\\').replaceAll(',', r'\,').replaceAll(';', r'\;').replaceAll('\n', r'\n');
    final b = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('N:${esc(c.lastName)};${esc(c.firstName)};;;')
      ..writeln('FN:${esc(c.fullName)}');
    if ((c.company ?? '').isNotEmpty) b.writeln('ORG:${esc(c.company)}');
    if ((c.position ?? '').isNotEmpty) b.writeln('TITLE:${esc(c.position)}');
    if ((c.phone ?? '').isNotEmpty) b.writeln('TEL;TYPE=CELL:${esc(c.phone)}');
    if ((c.email ?? '').isNotEmpty) b.writeln('EMAIL;TYPE=INTERNET:${esc(c.email)}');
    if ((c.website ?? '').isNotEmpty) b.writeln('URL:${esc(c.website)}');
    if ((c.address ?? '').isNotEmpty) b.writeln('ADR;TYPE=WORK:;;${esc(c.address)};;;;');
    b.writeln('END:VCARD');
    return b.toString();
  }

  static String _cell(String v) {
    // Neutralise spreadsheet formula injection, then quote.
    var s = v;
    if (s.isNotEmpty && '=+-@'.contains(s[0]) && !RegExp(r'^\+?\d[\d\s()\-]*$').hasMatch(s)) {
      s = "'$s";
    }
    if (s.contains(RegExp(r'[",\r\n]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  static String safeFileName(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');

  /// [origin] anchors the share popover on iPad (required there, ignored on
  /// phones).
  Future<void> shareText(
    String fileName,
    String content, {
    required String mime,
    String? subject,
    Rect? origin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}
