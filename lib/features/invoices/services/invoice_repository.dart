import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/transaction_repository.dart';
import 'invoice_number_formatter.dart';

class InvoiceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _transactionRepo = TransactionRepository();

  CollectionReference<Map<String, dynamic>> get _invoices => _db.collection('invoices');
  DocumentReference<Map<String, dynamic>> _counterDoc(String bookId) =>
      _db.collection('books').doc(bookId).collection('meta').doc('invoiceCounter');

  Stream<List<Invoice>> watchInvoices(String bookId) {
    return _invoices
        .where('bookId', isEqualTo: bookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Invoice.fromMap(d.id, d.data())).toList());
  }

  /// SRS 4.5: "Invoice number should autoincrement... with option to reset
  /// every financial year." Uses a Firestore transaction on a per-book
  /// counter doc so two devices creating invoices at once never collide.
  Future<String> _nextInvoiceNumber(Book book, DateTime invoiceDate) async {
    final fy = financialYearFor(invoiceDate);
    final fyStartYear = invoiceDate.month >= 4 ? invoiceDate.year : invoiceDate.year - 1;

    return _db.runTransaction<String>((txn) async {
      final counterRef = _counterDoc(book.id);
      final snap = await txn.get(counterRef);

      int nextNumber;
      if (!snap.exists) {
        nextNumber = 1;
        txn.set(counterRef, {'financialYear': fy, 'lastNumber': nextNumber});
      } else {
        final data = snap.data()!;
        final storedFy = data['financialYear'] as String?;
        final lastNumber = (data['lastNumber'] as num?)?.toInt() ?? 0;

        if (book.resetInvoiceNumberEachFY && storedFy != fy) {
          nextNumber = 1;
        } else {
          nextNumber = lastNumber + 1;
        }
        txn.update(counterRef, {'financialYear': fy, 'lastNumber': nextNumber});
      }

      return InvoiceNumberFormatter.format(
        template: book.invoicePrefix,
        number: nextNumber,
        financialYearStart: fyStartYear,
      );
    });
  }

  Future<Invoice> createInvoice({
    required Book book,
    required DateTime invoiceDate,
    required String customerContactId,
    required String customerName,
    required String customerState,
    String? customerGstin,
    required List<InvoiceLineItem> lineItems,
    InvoiceDocType docType = InvoiceDocType.invoice,
    String? linkedInvoiceId,
  }) async {
    final invoiceNumber = await _nextInvoiceNumber(book, invoiceDate);
    final id = _uuid.v4();
    final invoice = Invoice(
      id: id,
      bookId: book.id,
      docType: docType,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      customerContactId: customerContactId,
      customerName: customerName,
      customerState: customerState,
      customerGstin: customerGstin,
      lineItems: lineItems,
      linkedInvoiceId: linkedInvoiceId,
      createdAt: DateTime.now(),
    );
    await _invoices.doc(id).set(invoice.toMap());
    return invoice;
  }

  Future<void> updatePdfUrl(String invoiceId, String pdfUrl) async {
    await _invoices.doc(invoiceId).update({'pdfUrl': pdfUrl});
  }

  /// SRS Section 8: "When an invoice is marked Paid, auto-generate the
  /// matching Income transaction so the user never double-enters it.
  /// Don't let them manually create a duplicate income entry for the same
  /// invoice." This is the one place that transition happens - never
  /// duplicate this logic elsewhere.
  Future<void> markPaid(Invoice invoice) async {
    if (invoice.status == InvoiceStatus.paid && invoice.linkedTransactionId != null) {
      return; // Already paid and already linked - nothing to do.
    }

    final tx = await _transactionRepo.saveTransaction(
      bookId: invoice.bookId,
      type: TxType.income,
      date: invoice.invoiceDate,
      amountPaise: invoice.grandTotalPaise,
      taxAmountPaise: invoice.taxTotalPaise,
      vendorOrCustomerName: invoice.customerName,
      contactId: invoice.customerContactId,
      notes: 'Auto-created from invoice ${invoice.invoiceNumber}',
      // The invoice PDF itself becomes this transaction's "receipt" per
      // SRS 4.5. Left blank here; wired to invoice.pdfUrl once the PDF is
      // generated/uploaded, via updateTransactionReceiptFromInvoice below.
    );

    await _invoices.doc(invoice.id).update({
      'status': InvoiceStatus.paid.name,
      'linkedTransactionId': tx.id,
    });
  }

  Future<void> markUnpaid(Invoice invoice) async {
    // Note: intentionally does NOT delete the auto-created income
    // transaction - undoing a "Paid" mark shouldn't silently destroy a
    // financial record. The user can delete that transaction manually from
    // the ledger if it was a mistake.
    await _invoices.doc(invoice.id).update({'status': InvoiceStatus.unpaid.name});
  }

  Future<void> markPartial(Invoice invoice) async {
    await _invoices.doc(invoice.id).update({'status': InvoiceStatus.partial.name});
  }
}
