enum InvoiceStatus { unpaid, paid, partial }

/// SRS Section 4.5: "Support Credit Note / Debit Note linked to an
/// original invoice" - modeled as a doc type on the same Invoice
/// collection so they share numbering/PDF/share plumbing. `linkedInvoiceId`
/// points back to the original invoice for a credit/debit note.
enum InvoiceDocType { invoice, creditNote, debitNote }

class InvoiceLineItem {
  final String id;
  final String description;
  final String? hsnSac;
  final double qty;
  final int rateePaise; // per-unit rate, in paise
  final int discountPaise; // flat discount on this line, in paise
  final double taxRatePercent; // from TaxRuleConfig, never hardcoded

  InvoiceLineItem({
    required this.id,
    required this.description,
    this.hsnSac,
    required this.qty,
    required this.rateePaise,
    this.discountPaise = 0,
    required this.taxRatePercent,
  });

  /// qty * rate - discount, before tax.
  int get taxableAmountPaise => (qty * rateePaise).round() - discountPaise;

  int get taxAmountPaise => (taxableAmountPaise * taxRatePercent / 100).round();

  int get totalAmountPaise => taxableAmountPaise + taxAmountPaise;

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) => InvoiceLineItem(
        id: map['id'] as String,
        description: map['description'] as String? ?? '',
        hsnSac: map['hsnSac'] as String?,
        qty: (map['qty'] as num?)?.toDouble() ?? 1,
        rateePaise: (map['rateePaise'] as num?)?.toInt() ?? 0,
        discountPaise: (map['discountPaise'] as num?)?.toInt() ?? 0,
        taxRatePercent: (map['taxRatePercent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'hsnSac': hsnSac,
        'qty': qty,
        'rateePaise': rateePaise,
        'discountPaise': discountPaise,
        'taxRatePercent': taxRatePercent,
      };
}

class Invoice {
  final String id;
  final String bookId;
  final InvoiceDocType docType;
  final String invoiceNumber; // e.g. "INV-2026-0001"
  final DateTime invoiceDate;
  final String customerContactId;
  final String customerName; // denormalized for display without a join
  final String customerState;
  final String? customerGstin;
  final List<InvoiceLineItem> lineItems;
  final InvoiceStatus status;
  final String? linkedTransactionId; // set once marked Paid
  final String? linkedInvoiceId; // for credit/debit notes
  final String? pdfUrl;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.bookId,
    this.docType = InvoiceDocType.invoice,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerContactId,
    required this.customerName,
    required this.customerState,
    this.customerGstin,
    required this.lineItems,
    this.status = InvoiceStatus.unpaid,
    this.linkedTransactionId,
    this.linkedInvoiceId,
    this.pdfUrl,
    required this.createdAt,
  });

  int get taxableTotalPaise =>
      lineItems.fold(0, (a, li) => a + li.taxableAmountPaise);
  int get taxTotalPaise => lineItems.fold(0, (a, li) => a + li.taxAmountPaise);
  int get grandTotalPaise => taxableTotalPaise + taxTotalPaise;

  factory Invoice.fromMap(String id, Map<String, dynamic> map) => Invoice(
        id: id,
        bookId: map['bookId'] as String,
        docType: InvoiceDocType.values.firstWhere(
          (e) => e.name == map['docType'],
          orElse: () => InvoiceDocType.invoice,
        ),
        invoiceNumber: map['invoiceNumber'] as String? ?? '',
        invoiceDate:
            DateTime.tryParse(map['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
        customerContactId: map['customerContactId'] as String? ?? '',
        customerName: map['customerName'] as String? ?? '',
        customerState: map['customerState'] as String? ?? '',
        customerGstin: map['customerGstin'] as String?,
        lineItems: ((map['lineItems'] as List?) ?? [])
            .map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => InvoiceStatus.unpaid,
        ),
        linkedTransactionId: map['linkedTransactionId'] as String?,
        linkedInvoiceId: map['linkedInvoiceId'] as String?,
        pdfUrl: map['pdfUrl'] as String?,
        createdAt:
            DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'docType': docType.name,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate.toIso8601String(),
        'customerContactId': customerContactId,
        'customerName': customerName,
        'customerState': customerState,
        'customerGstin': customerGstin,
        'lineItems': lineItems.map((e) => e.toMap()).toList(),
        'status': status.name,
        'linkedTransactionId': linkedTransactionId,
        'linkedInvoiceId': linkedInvoiceId,
        'pdfUrl': pdfUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  Invoice copyWith({
    InvoiceStatus? status,
    String? linkedTransactionId,
    String? pdfUrl,
    List<InvoiceLineItem>? lineItems,
  }) {
    return Invoice(
      id: id,
      bookId: bookId,
      docType: docType,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      customerContactId: customerContactId,
      customerName: customerName,
      customerState: customerState,
      customerGstin: customerGstin,
      lineItems: lineItems ?? this.lineItems,
      status: status ?? this.status,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      linkedInvoiceId: linkedInvoiceId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt,
    );
  }
}
