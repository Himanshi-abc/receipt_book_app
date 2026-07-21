import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/gst_service.dart';
import '../../../core/utils/money.dart';
import 'amount_in_words.dart';

class InvoicePdfService {
  InvoicePdfService._();

  /// [logoBytes] is optional - pass null if the Business Book has no logo
  /// uploaded yet; the PDF still renders cleanly without one.
  static Future<Uint8List> generate({
    required Book book,
    required Invoice invoice,
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document();

    // Tax split is computed once here for the whole invoice, using the
    // book's state vs the customer's state - CGST+SGST split 50/50 if
    // same state, IGST at full rate if not (SRS Section 8).
    final sameState = book.state?.trim().toLowerCase() ==
        invoice.customerState.trim().toLowerCase();

    final breakups = invoice.lineItems
        .map((li) => GstService.computeBreakup(
              taxableAmountPaise: li.taxableAmountPaise,
              ratePercent: li.taxRatePercent,
              businessState: book.state ?? '',
              customerState: invoice.customerState,
            ))
        .toList();

    final totalCgst = breakups.fold<int>(0, (a, b) => a + b.cgstPaise);
    final totalSgst = breakups.fold<int>(0, (a, b) => a + b.sgstPaise);
    final totalIgst = breakups.fold<int>(0, (a, b) => a + b.igstPaise);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(book, invoice, logoBytes),
          pw.SizedBox(height: 16),
          _buildPartyDetails(book, invoice),
          pw.SizedBox(height: 16),
          _buildLineItemsTable(invoice),
          pw.SizedBox(height: 12),
          _buildTotalsBlock(
            invoice: invoice,
            sameState: sameState,
            totalCgst: totalCgst,
            totalSgst: totalSgst,
            totalIgst: totalIgst,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Amount in words: ${AmountInWords.paiseToWords(invoice.grandTotalPaise)}',
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'This is a computer-generated invoice.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(Book book, Invoice invoice, Uint8List? logoBytes) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Container(
                height: 48,
                width: 48,
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Image(pw.MemoryImage(logoBytes)),
              ),
            pw.Text(book.name,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (book.gstin != null) pw.Text('GSTIN: ${book.gstin}', style: const pw.TextStyle(fontSize: 10)),
            if (book.address != null) pw.Text(book.address!, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              invoice.docType == InvoiceDocType.creditNote
                  ? 'CREDIT NOTE'
                  : invoice.docType == InvoiceDocType.debitNote
                      ? 'DEBIT NOTE'
                      : 'TAX INVOICE',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('No: ${invoice.invoiceNumber}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              'Date: ${invoice.invoiceDate.day}/${invoice.invoiceDate.month}/${invoice.invoiceDate.year}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPartyDetails(Book book, Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(invoice.customerName, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('State: ${invoice.customerState}', style: const pw.TextStyle(fontSize: 10)),
          if (invoice.customerGstin != null)
            pw.Text('GSTIN: ${invoice.customerGstin}', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildLineItemsTable(Invoice invoice) {
    final headers = ['#', 'Description', 'HSN/SAC', 'Qty', 'Rate', 'Tax %', 'Amount'];
    final rows = <List<String>>[];
    for (int i = 0; i < invoice.lineItems.length; i++) {
      final li = invoice.lineItems[i];
      rows.add([
        '${i + 1}',
        li.description,
        li.hsnSac ?? '-',
        li.qty.toStringAsFixed(li.qty == li.qty.roundToDouble() ? 0 : 2),
        Money.format(li.rateePaise),
        '${li.taxRatePercent.toStringAsFixed(li.taxRatePercent == li.taxRatePercent.roundToDouble() ? 0 : 2)}%',
        Money.format(li.totalAmountPaise),
      ]);
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(1.3),
      },
    );
  }

  static pw.Widget _buildTotalsBlock({
    required Invoice invoice,
    required bool sameState,
    required int totalCgst,
    required int totalSgst,
    required int totalIgst,
  }) {
    pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            row('Taxable Amount', Money.format(invoice.taxableTotalPaise)),
            if (sameState) ...[
              row('CGST', Money.format(totalCgst)),
              row('SGST', Money.format(totalSgst)),
            ] else
              row('IGST', Money.format(totalIgst)),
            pw.Divider(),
            row('Grand Total', Money.format(invoice.grandTotalPaise), bold: true),
          ],
        ),
      ),
    );
  }
}
