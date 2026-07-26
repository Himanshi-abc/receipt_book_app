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
  /// every financial year."
  ///
  /// NOTE: this used to run inside `_db.runTransaction(...)` for atomicity
  /// across concurrent devices. On the unofficial Windows desktop Firestore
  /// plugin, `runTransaction` is known to be unstable and can crash the
  /// native process outright (no Dart exception - the app just dies).
  /// Since a single user only ever creates one invoice at a time in
  /// practice, a plain read-then-write is safe enough here and sidesteps
  /// that crash. If you later need true multi-device concurrency safety,
  /// re-introduce a transaction - but test it on Android first, since the
  /// mobile Firestore plugin doesn't have this issue.
  Future<String> _nextInvoiceNumber(Book book, DateTime invoiceDate) async {
    final fy = financialYearFor(invoiceDate);
    final fyStartYear = invoiceDate.month >= 4 ? invoiceDate.year : invoiceDate.year - 1;
    final counterRef = _counterDoc(book.id);

    final snap = await counterRef.get();
    int nextNumber;
    if (!snap.exists) {
      nextNumber = 1;
      await counterRef.set({'financialYear': fy, 'lastNumber': nextNumber});
    } else {
      final data = snap.data()!;
      final storedFy = data['financialYear'] as String?;
      final lastNumber = (data['lastNumber'] as num?)?.toInt() ?? 0;

      if (book.resetInvoiceNumberEachFY && storedFy != fy) {
        nextNumber = 1;
      } else {
        nextNumber = lastNumber + 1;
      }
      await counterRef.set({'financialYear': fy, 'lastNumber': nextNumber});
    }

    return InvoiceNumberFormatter.format(
      template: book.invoicePrefix,
      number: nextNumber,
      financialYearStart: fyStartYear,
    );
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
    BillDirection billDirection = BillDirection.sales,
    int discountPaise = 0,
    String? additionalChargeDescription,
    int additionalChargePaise = 0,
    int amountReceivedPaise = 0,
    String? paymentMode,
    String? linkedInvoiceId,
  }) async {
    final invoiceNumber = await _nextInvoiceNumber(book, invoiceDate);
    final id = _uuid.v4();
    var invoice = Invoice(
      id: id,
      bookId: book.id,
      docType: docType,
      billDirection: billDirection,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      customerContactId: customerContactId,
      customerName: customerName,
      customerState: customerState,
      customerGstin: customerGstin,
      lineItems: lineItems,
      discountPaise: discountPaise,
      additionalChargeDescription: additionalChargeDescription,
      additionalChargePaise: additionalChargePaise,
      amountReceivedPaise: amountReceivedPaise,
      paymentMode: paymentMode,
      linkedInvoiceId: linkedInvoiceId,
      createdAt: DateTime.now(),
    );

    final grandTotal = invoice.grandTotalPaise;
    invoice = invoice.copyWith(
      status: amountReceivedPaise <= 0
          ? InvoiceStatus.unpaid
          : (amountReceivedPaise >= grandTotal ? InvoiceStatus.paid : InvoiceStatus.partial),
    );

    await _invoices.doc(id).set(invoice.toMap());

    // Book whatever was actually received right away - see _recordPayment.
    if (amountReceivedPaise > 0) {
      final txId = await _recordPayment(invoice, amountReceivedPaise);
      invoice = invoice.copyWith(linkedTransactionId: txId);
    }

    return invoice;
  }

  Future<void> updatePdfUrl(String invoiceId, String pdfUrl) async {
    await _invoices.doc(invoiceId).update({'pdfUrl': pdfUrl});
  }

  /// SRS Section 8: "When an invoice is marked Paid, auto-generate the
  /// matching Income transaction so the user never double-enters it.
  /// Don't let them manually create a duplicate income entry for the same
  /// invoice." This is the one place a payment turns into a ledger
  /// transaction - never duplicate this logic elsewhere. Sales books
  /// income; Purchase (money going out to a Supplier) books expense.
  Future<String> _recordPayment(Invoice invoice, int amountPaise) async {
    final type =
        invoice.billDirection == BillDirection.purchase ? TxType.expense : TxType.income;
    final kind = invoice.billDirection == BillDirection.purchase ? 'purchase bill' : 'invoice';
    final tx = await _transactionRepo.saveTransaction(
      bookId: invoice.bookId,
      type: type,
      date: invoice.invoiceDate,
      amountPaise: amountPaise,
      taxAmountPaise: invoice.taxTotalPaise,
      vendorOrCustomerName: invoice.customerName,
      contactId: invoice.customerContactId,
      notes: 'Auto-created from $kind ${invoice.invoiceNumber}',
      // The invoice PDF itself becomes this transaction's "receipt" per
      // SRS 4.5. Left blank here; wired to invoice.pdfUrl once the PDF is
      // generated/uploaded, via updateTransactionReceiptFromInvoice below.
    );
    await _invoices.doc(invoice.id).update({'linkedTransactionId': tx.id});
    return tx.id;
  }

  Future<void> markPaid(Invoice invoice) async {
    if (invoice.status == InvoiceStatus.paid && invoice.linkedTransactionId != null) {
      return; // Already paid and already linked - nothing to do.
    }

    // Only book what hasn't already been recorded (e.g. a partial amount
    // captured at creation time) - avoids double-counting income/expense.
    final remaining = invoice.grandTotalPaise - invoice.amountReceivedPaise;
    String? txId = invoice.linkedTransactionId;
    if (remaining > 0) {
      txId = await _recordPayment(invoice, remaining);
    }

    await _invoices.doc(invoice.id).update({
      'status': InvoiceStatus.paid.name,
      'amountReceivedPaise': invoice.grandTotalPaise,
      if (txId != null) 'linkedTransactionId': txId,
    });
  }

  Future<void> markUnpaid(Invoice invoice) async {
    // Note: intentionally does NOT delete the auto-created income/expense
    // transaction - undoing a "Paid" mark shouldn't silently destroy a
    // financial record. The user can delete that transaction manually from
    // the ledger if it was a mistake.
    await _invoices.doc(invoice.id).update({'status': InvoiceStatus.unpaid.name});
  }

  Future<void> markPartial(Invoice invoice) async {
    await _invoices.doc(invoice.id).update({'status': InvoiceStatus.partial.name});
  }
}
