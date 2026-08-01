import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/invoice_template.dart';
import '../../../core/services/gst_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';
import 'amount_in_words.dart';

class InvoicePdfService {
  InvoicePdfService._();

  /// [logoBytes] is optional - pass null if the Business Book has no logo
  /// uploaded yet; the PDF still renders cleanly without one.
  ///
  /// [templateId] picks the invoice's look (see invoice_template.dart) -
  /// normally just `book.invoiceTemplateId`, so every invoice a Business
  /// Book generates shares the one template it has selected.
  static Future<Uint8List> generate({
    required Book book,
    required Invoice invoice,
    Uint8List? logoBytes,
    String? templateId,
  }) async {
    final style = invoiceTemplateById(templateId ?? book.invoiceTemplateId);
    final doc = pw.Document(theme: await PdfFonts.theme());

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
          _buildHeader(book, invoice, logoBytes, style),
          pw.SizedBox(height: 16),
          _buildPartyDetails(book, invoice),
          pw.SizedBox(height: 16),
          _buildLineItemsTable(invoice, style),
          pw.SizedBox(height: 12),
          _buildTotalsBlock(
            invoice: invoice,
            sameState: sameState,
            totalCgst: totalCgst,
            totalSgst: totalSgst,
            totalIgst: totalIgst,
            style: style,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Amount in words: ${AmountInWords.paiseToWords(invoice.grandTotalPaise)}',
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
          ),
          if (!book.bankDetails.isEmpty) ...[
            pw.SizedBox(height: 16),
            _buildBankDetailsBlock(book, style),
          ],
          pw.SizedBox(height: 24),
          _buildFooter(book),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(
    Book book,
    Invoice invoice,
    Uint8List? logoBytes,
    InvoiceTemplateStyle style,
  ) {
    final primary = PdfColor.fromInt(style.primaryColor);
    final isBand = style.headerLayout == InvoiceHeaderLayout.colorBand;

    // Title/body text colors depend on what background this ends up on -
    // primary-colored text on white for plain/sidebar, or light/dark text
    // on the primary-colored band itself for colorBand.
    final titleColor =
        isBand ? (style.lightTextOnAccent ? PdfColors.white : PdfColors.black) : primary;
    final bodyColor = isBand
        ? (style.lightTextOnAccent ? PdfColors.grey200 : PdfColors.grey800)
        : PdfColors.grey800;

    final displayName =
        book.brandName?.trim().isNotEmpty == true ? book.brandName!.trim() : book.name;

    final content = pw.Row(
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
            pw.Text(displayName,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: titleColor)),
            if (book.gstin != null)
              pw.Text('GSTIN: ${book.gstin}', style: pw.TextStyle(fontSize: 10, color: bodyColor)),
            if (book.address != null)
              pw.Text(book.address!, style: pw.TextStyle(fontSize: 10, color: bodyColor)),
            if (book.phone != null)
              pw.Text('Ph: ${book.phone}', style: pw.TextStyle(fontSize: 10, color: bodyColor)),
            if (book.website != null)
              pw.Text(book.website!, style: pw.TextStyle(fontSize: 10, color: bodyColor)),
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
                      : invoice.billDirection == BillDirection.purchase
                          ? 'PURCHASE BILL'
                          : 'TAX INVOICE',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: titleColor),
            ),
            pw.Text('No: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 10, color: bodyColor)),
            pw.Text(
              'Date: ${invoice.invoiceDate.day}/${invoice.invoiceDate.month}/${invoice.invoiceDate.year}',
              style: pw.TextStyle(fontSize: 10, color: bodyColor),
            ),
            pw.Text(
              'Due Date: ${invoice.effectiveDueDate.day}/${invoice.effectiveDueDate.month}/${invoice.effectiveDueDate.year}',
              style: pw.TextStyle(fontSize: 10, color: bodyColor),
            ),
          ],
        ),
      ],
    );

    switch (style.headerLayout) {
      case InvoiceHeaderLayout.plain:
        return content;
      case InvoiceHeaderLayout.colorBand:
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: content,
        );
      case InvoiceHeaderLayout.sidebarAccent:
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(width: 6, decoration: pw.BoxDecoration(color: primary)),
            pw.SizedBox(width: 14),
            pw.Expanded(child: content),
          ],
        );
    }
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

  static pw.Widget _buildLineItemsTable(Invoice invoice, InvoiceTemplateStyle style) {
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

    final primary = PdfColor.fromInt(style.primaryColor);
    final accent = PdfColor.fromInt(style.accentColor);

    pw.TableBorder? border;
    pw.BoxDecoration? headerDecoration;
    pw.BoxDecoration? oddRowDecoration;
    pw.TextStyle headerStyle;

    switch (style.tableStyle) {
      case InvoiceTableStyle.bordered:
        border = pw.TableBorder.all(color: PdfColors.grey400, width: 0.5);
        headerDecoration = pw.BoxDecoration(color: accent);
        headerStyle =
            pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey900);
        break;
      case InvoiceTableStyle.striped:
        headerDecoration = pw.BoxDecoration(color: primary);
        oddRowDecoration = pw.BoxDecoration(color: accent);
        headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white);
        break;
      case InvoiceTableStyle.minimalLines:
        border = pw.TableBorder(
          horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          bottom: pw.BorderSide(color: primary, width: 1),
        );
        headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: primary);
        break;
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: headerStyle,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      border: border,
      headerDecoration: headerDecoration,
      oddRowDecoration: oddRowDecoration,
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
    required InvoiceTemplateStyle style,
  }) {
    final primary = PdfColor.fromInt(style.primaryColor);

    pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: bold ? 11 : 10,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: bold ? primary : PdfColors.grey900)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: bold ? 11 : 10,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: bold ? primary : PdfColors.grey900)),
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
            if (invoice.discountPaise > 0)
              row('Discount', '- ${Money.format(invoice.discountPaise)}'),
            if (invoice.additionalChargePaise > 0)
              row(invoice.additionalChargeDescription?.trim().isNotEmpty == true
                  ? invoice.additionalChargeDescription!
                  : 'Additional Charge', Money.format(invoice.additionalChargePaise)),
            pw.Divider(color: primary),
            row('Grand Total', Money.format(invoice.grandTotalPaise), bold: true),
            if (invoice.amountReceivedPaise > 0) ...[
              row('Amount Received', Money.format(invoice.amountReceivedPaise)),
              row('Balance Due', Money.format(invoice.balanceDuePaise), bold: true),
            ],
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildBankDetailsBlock(Book book, InvoiceTemplateStyle style) {
    final b = book.bankDetails;
    final primary = PdfColor.fromInt(style.primaryColor);
    pw.Widget line(String label, String? value) => value == null || value.trim().isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 9)),
          );

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: primary, width: 0.75))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Bank Details for Payment',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primary)),
          pw.SizedBox(height: 4),
          line('Account Holder', b.accountHolderName),
          line('Bank', b.bankName),
          line('Account No.', b.accountNumber),
          line('IFSC', b.ifscCode),
        ],
      ),
    );
  }

  /// Reserves the signature line/label whenever a signature has been
  /// uploaded - actually rendering the image itself would need it fetched
  /// as bytes first (same as logoBytes above), which no caller wires up
  /// yet; left as a placeholder line rather than blocking this feature on it.
  static pw.Widget _buildFooter(Book book) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'This is a computer-generated invoice.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        if (book.signatureUrl != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 32),
              pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
      ],
    );
  }
}
