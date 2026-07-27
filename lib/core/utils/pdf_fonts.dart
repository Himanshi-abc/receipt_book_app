import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Shared PDF theme for every generated PDF (invoice, product list, khata
/// ledger). The `pdf` package's built-in fonts (Helvetica etc.) don't cover
/// the ₹ (Indian Rupee Sign, U+20B9) glyph, which throws "Unable to find a
/// font to draw..." the moment any amount renders. Noto Sans covers it, so
/// every pw.Document should be built with this as its `theme`.
class PdfFonts {
  PdfFonts._();

  static Future<pw.ThemeData> theme() async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }
}
