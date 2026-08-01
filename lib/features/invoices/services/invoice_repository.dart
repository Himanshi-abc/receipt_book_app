import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/transaction_repository.dart';
import '../../khata/services/khata_entry_repository.dart';
import 'invoice_number_formatter.dart';

class InvoiceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _transactionRepo = TransactionRepository();
  final _khataEntryRepo = KhataEntryRepository();

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
    DateTime? dueDate,
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
      dueDate: dueDate,
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

    await _syncKhataEntry(invoice);

    return invoice;
  }

  Future<void> updatePdfUrl(String invoiceId, String pdfUrl) async {
    await _invoices.doc(invoiceId).update({'pdfUrl': pdfUrl});
  }

  /// Edits an existing Sale/Purchase bill in place (same id/invoiceNumber).
  ///
  /// Note: unlike [createInvoice], this does NOT reconcile the
  /// auto-created payment transaction if [amountReceivedPaise] changes from
  /// what it was - same manual-correction tradeoff [markUnpaid] already
  /// takes with the linked transaction, rather than silently rewriting a
  /// financial record the user may have already reconciled elsewhere.
  Future<Invoice> updateInvoice({
    required Invoice existing,
    required DateTime invoiceDate,
    DateTime? dueDate,
    required String customerContactId,
    required String customerName,
    required String customerState,
    String? customerGstin,
    required List<InvoiceLineItem> lineItems,
    int discountPaise = 0,
    String? additionalChargeDescription,
    int additionalChargePaise = 0,
    int amountReceivedPaise = 0,
    String? paymentMode,
  }) async {
    // Built directly (not via copyWith) since customerGstin and
    // additionalChargeDescription must be assignable back to null on edit -
    // copyWith's `newValue ?? oldValue` pattern can't express "clear this".
    var invoice = Invoice(
      id: existing.id,
      bookId: existing.bookId,
      docType: existing.docType,
      billDirection: existing.billDirection,
      invoiceNumber: existing.invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      customerContactId: customerContactId,
      customerName: customerName,
      customerState: customerState,
      customerGstin: customerGstin,
      lineItems: lineItems,
      discountPaise: discountPaise,
      additionalChargeDescription: additionalChargeDescription,
      additionalChargePaise: additionalChargePaise,
      status: existing.status,
      amountReceivedPaise: amountReceivedPaise,
      paymentMode: paymentMode,
      linkedTransactionId: existing.linkedTransactionId,
      linkedInvoiceId: existing.linkedInvoiceId,
      pdfUrl: existing.pdfUrl,
      createdAt: existing.createdAt,
    );

    final grandTotal = invoice.grandTotalPaise;
    invoice = invoice.copyWith(
      status: amountReceivedPaise <= 0
          ? InvoiceStatus.unpaid
          : (amountReceivedPaise >= grandTotal ? InvoiceStatus.paid : InvoiceStatus.partial),
    );

    await _invoices.doc(invoice.id).set(invoice.toMap());
    await _syncKhataEntry(invoice);
    return invoice;
  }

  /// Keeps the matching Customer/Supplier's khata (Customers/Suppliers
  /// section - "manage credits and outstanding amount") in sync with this
  /// bill's balance due, the same way [_recordPayment] keeps the ledger in
  /// sync with payments received. Uses the invoice's own id as the khata
  /// entry's id, so re-saving an edited invoice updates that same entry in
  /// place instead of creating a duplicate (see
  /// KhataEntryRepository.saveEntry's `id` param).
  ///
  /// `youGave` is used for both Sales and Purchase bills' outstanding due:
  /// per khata_balance.dart, a positive running balance reads as "You'll
  /// get" for a Customer and "You'll pay" for a Supplier - exactly what an
  /// unpaid Sales invoice (customer owes you) and an unpaid Purchase bill
  /// (you owe the supplier) should each show.
  Future<void> _syncKhataEntry(Invoice invoice) async {
    if (invoice.customerContactId.isEmpty) return;
    final due = invoice.balanceDuePaise;
    if (due <= 0) {
      // Fully paid (or credited) - no outstanding due; clear any entry left
      // over from a previously unpaid/partial state.
      await _khataEntryRepo.deleteById(invoice.id);
      return;
    }
    final kind = invoice.billDirection == BillDirection.purchase ? 'purchase bill' : 'invoice';
    await _khataEntryRepo.saveEntry(
      id: invoice.id,
      bookId: invoice.bookId,
      contactId: invoice.customerContactId,
      type: KhataEntryType.youGave,
      amountPaise: due,
      description: 'Auto-created from $kind ${invoice.invoiceNumber}',
      date: invoice.invoiceDate,
    );
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

    // Fully paid now - no outstanding due left for this bill.
    await _khataEntryRepo.deleteById(invoice.id);
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

  /// Permanently removes a Sale/Purchase bill.
  ///
  /// Note: same tradeoff as [markUnpaid] for the auto-created income/expense
  /// transaction - this intentionally does NOT delete it (linked via
  /// [Invoice.linkedTransactionId]); that's a financial record the user may
  /// already be relying on, so they can remove it manually if it was a
  /// mistake. The auto-created khata (outstanding due) entry is different:
  /// it exists purely to mirror this bill's balance, so it IS removed here
  /// - otherwise a deleted bill would leave a phantom amount owed.
  Future<void> deleteInvoice(String invoiceId) async {
    await _invoices.doc(invoiceId).delete();
    await _khataEntryRepo.deleteById(invoiceId);
  }
}
