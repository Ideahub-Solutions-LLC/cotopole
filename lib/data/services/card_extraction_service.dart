import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/models.dart';
import 'card_text_parser.dart';
import 'vcard_parser.dart';

class ExtractionResult {
  const ExtractionResult({
    required this.draft,
    required this.method,
    this.rawText = '',
    this.uncertain = const {},
    this.error,
  });

  final ContactDraft draft;
  final CaptureMethod method;
  final String rawText;
  final Set<String> uncertain;
  final String? error;

  bool get isEmpty => draft.isEmpty;
}

/// On-device business-card extraction — no network, no cloud AI.
///
/// Mirrors the backend's strategy: QR / vCard first (instant and exact),
/// then text recognition with heuristic field parsing. Uses Google ML Kit,
/// which runs fully offline on both iOS and Android.
class CardExtractionService {
  Future<ExtractionResult> extract(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    ContactDraft? qrDraft;

    // 1) QR / vCard
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final codes = await scanner.processImage(input);
      for (final c in codes) {
        final raw = c.rawValue;
        if (raw != null && VCardParser.looksLikeContact(raw)) {
          qrDraft = VCardParser.parse(raw);
          if (qrDraft != null) break;
        }
      }
    } catch (_) {
      // QR detection is opportunistic; fall through to OCR.
    } finally {
      await scanner.close();
    }

    final qrComplete = qrDraft != null &&
        (qrDraft.firstName.isNotEmpty || qrDraft.lastName.isNotEmpty) &&
        (qrDraft.phone.isNotEmpty || qrDraft.email.isNotEmpty);
    if (qrComplete) {
      return ExtractionResult(draft: qrDraft, method: CaptureMethod.qr);
    }

    // 2) Text recognition
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(input);
      final lines = <OcrLine>[
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(
              line.text,
              height: line.boundingBox.height,
              top: line.boundingBox.top,
            ),
      ]..sort((a, b) => a.top.compareTo(b.top));
      final parsed = CardTextParser.parse(lines);

      if (qrDraft != null) {
        // Partial QR + OCR → QR values win, OCR fills the gaps.
        return ExtractionResult(
          draft: qrDraft.mergeMissing(parsed.draft),
          method: CaptureMethod.mixed,
          rawText: result.text,
          uncertain: parsed.uncertain,
        );
      }
      return ExtractionResult(
        draft: parsed.draft,
        method: CaptureMethod.image,
        rawText: result.text,
        uncertain: parsed.uncertain,
        error: parsed.draft.isEmpty ? 'No readable text found on the card.' : null,
      );
    } catch (e) {
      return ExtractionResult(
        draft: qrDraft ?? const ContactDraft(),
        method: qrDraft != null ? CaptureMethod.qr : CaptureMethod.image,
        error: 'Could not read the card on this device. Please type the details.',
      );
    } finally {
      await recognizer.close();
    }
  }
}
