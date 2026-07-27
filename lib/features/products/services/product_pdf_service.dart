import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/models/book_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';

/// Exports the product/service catalog as a PDF - one row per product,
/// showing Code/Name/Price so it can be printed or shared as a quick
/// reference sheet (e.g. for a shop counter).
class ProductPdfService {
  ProductPdfService._();

  static Future<Uint8List> generate({
    required Book book,
    required List<Product> products,
  }) async {
    final doc = pw.Document(theme: await PdfFonts.theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(book.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Product / Service List', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          _buildTable(products),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildTable(List<Product> products) {
    final headers = ['Code', 'Name', 'Price'];
    final rows = products
        .map((p) => [
              p.productCode?.toString() ?? '-',
              p.name,
              Money.format(p.sellingPricePaise),
            ])
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
      },
    );
  }
}
