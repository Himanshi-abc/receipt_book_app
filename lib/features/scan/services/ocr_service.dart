import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final DateTime? date;
  final int? amountPaise;
  final int? taxAmountPaise;
  final String? vendorName;
  final String rawText;
  final bool success;

  OcrResult({
    this.date,
    this.amountPaise,
    this.taxAmountPaise,
    this.vendorName,
    required this.rawText,
    required this.success,
  });

  factory OcrResult.failed() =>
      OcrResult(rawText: '', success: false);
}

/// SRS Section 4.2 / Section 8: "OCR is a convenience, not a requirement.
/// Manual entry must always work, even with zero internet and zero OCR
/// confidence." Google ML Kit runs fully on-device, so it also satisfies
/// "no internet" for the OCR step itself - only the eventual cloud sync of
/// the transaction needs connectivity, not the recognition.
///
/// This is a heuristic MVP parser, not a production-grade receipt parser.
/// It is intentionally forgiving: any field it can't confidently find is
/// left null so the review form just shows that field blank rather than
/// guessing wrong.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      final text = recognized.text;
      if (text.trim().isEmpty) return OcrResult.failed();

      return OcrResult(
        date: _extractDate(text),
        amountPaise: _extractAmountPaise(text, taxHint: false),
        taxAmountPaise: _extractAmountPaise(text, taxHint: true),
        vendorName: _extractVendor(recognized),
        rawText: text,
        success: true,
      );
    } catch (_) {
      // Never throw up to the UI - SRS requires the blank form fallback.
      return OcrResult.failed();
    }
  }

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'), // 12/07/2026
      RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})'), // 2026-07-12
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      try {
        if (match.group(1)!.length == 4) {
          return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!),
              int.parse(match.group(3)!));
        } else {
          var year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
          return DateTime(year, int.parse(match.group(2)!), int.parse(match.group(1)!));
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  int? _extractAmountPaise(String text, {required bool taxHint}) {
    final lines = text.split('\n');
    final keywords = taxHint
        ? ['gst', 'tax', 'cgst', 'sgst', 'igst']
        : ['total', 'grand total', 'amount', 'net payable', 'balance due'];

    final amountPattern = RegExp(r'(\d[\d,]*\.?\d{0,2})');

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (keywords.any((k) => lower.contains(k))) {
        final match = amountPattern.firstMatch(line);
        if (match != null) {
          final cleaned = match.group(1)!.replaceAll(',', '');
          final value = double.tryParse(cleaned);
          if (value != null) return (value * 100).round();
        }
      }
    }
    return null;
  }

  String? _extractVendor(RecognizedText recognized) {
    // Heuristic: the vendor/shop name is very often the first non-empty,
    // reasonably short line at the top of the receipt.
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.length >= 3 && t.length <= 40 && !RegExp(r'^\d').hasMatch(t)) {
          return t;
        }
      }
    }
    return null;
  }

  void dispose() => _recognizer.close();
}
