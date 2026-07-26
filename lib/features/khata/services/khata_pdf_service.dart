import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/models/book_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/utils/money.dart';

/// Same shape as InvoicePdfService: a single pw.Document/pw.MultiPage built
/// from small private builder functions.
class KhataPdfService {
  KhataPdfService._();

  /// [entries] must be chronological (oldest first); [runningBalances] must
  /// be the same length/order (see khata_balance.dart's runningBalances).
  static Future<Uint8List> generate({
    required Book book,
    required Contact contact,
    required List<KhataEntry> entries,
    required List<int> runningBalances,
  }) async {
    final doc = pw.Document();
    final finalBalance = runningBalances.isEmpty ? 0 : runningBalances.last;
    final isCustomer = contact.type == ContactType.customer;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(book, contact),
          pw.SizedBox(height: 16),
          _buildEntriesTable(entries, runningBalances),
          pw.SizedBox(height: 12),
          _buildBalanceBlock(finalBalance, isCustomer),
          pw.SizedBox(height: 24),
          pw.Text(
            'This is a computer-generated ledger statement.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(Book book, Contact contact) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(book.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (book.gstin != null) pw.Text('GSTIN: ${book.gstin}', style: const pw.TextStyle(fontSize: 10)),
            if (book.address != null) pw.Text(book.address!, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('LEDGER STATEMENT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(contact.name, style: const pw.TextStyle(fontSize: 10)),
            if (contact.phone != null) pw.Text(contact.phone!, style: const pw.TextStyle(fontSize: 10)),
            if (contact.gstin != null) pw.Text('GSTIN: ${contact.gstin}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildEntriesTable(List<KhataEntry> entries, List<int> runningBalances) {
    final headers = ['Date', 'Description', 'You Gave', 'You Got', 'Balance'];
    final rows = <List<String>>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      rows.add([
        '${e.date.day}/${e.date.month}/${e.date.year}',
        e.description ?? '-',
        e.type == KhataEntryType.youGave ? Money.format(e.amountPaise) : '-',
        e.type == KhataEntryType.youGot ? Money.format(e.amountPaise) : '-',
        Money.format(runningBalances[i].abs()),
      ]);
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  static pw.Widget _buildBalanceBlock(int finalBalance, bool isCustomer) {
    final label = finalBalance == 0
        ? 'Settled up'
        : (finalBalance > 0
            ? (isCustomer ? "You'll get" : "You'll pay")
            : (isCustomer ? "You'll pay" : "You'll get"));
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(Money.format(finalBalance.abs()),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
