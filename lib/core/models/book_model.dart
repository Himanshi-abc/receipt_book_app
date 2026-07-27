enum BookType { individual, business }

/// Optional bank details for a Business Book, shown on invoices so a
/// customer knows where to send payment. Every field is optional - the
/// whole thing is meant to be filled in only if the business wants to
/// accept bank transfers.
class BankAccountDetails {
  final String? accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;

  BankAccountDetails({
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
  });

  bool get isEmpty =>
      accountHolderName == null &&
      bankName == null &&
      accountNumber == null &&
      ifscCode == null;

  factory BankAccountDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BankAccountDetails();
    return BankAccountDetails(
      accountHolderName: map['accountHolderName'] as String?,
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      ifscCode: map['ifscCode'] as String?,
    );
  }

  /// Null when every field is empty, so an untouched Book never persists
  /// an empty-but-present bankDetails map.
  Map<String, dynamic>? toMap() {
    if (isEmpty) return null;
    return {
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
    };
  }
}

class Book {
  final String id;
  final String userId;
  final BookType type;
  final String name;
  final String? gstin;
  final String? state;
  final String? address;
  final String? logoUrl;
  final String invoicePrefix;
  /// SRS 4.5: "invoice number should autoincrement, format configurable per
  /// Business Book (e.g., 'INV-2026-0001'), with option to reset every
  /// financial year."
  final bool resetInvoiceNumberEachFY;
  final DateTime createdAt;

  /// Only meaningful for business books under Single Book Plan - the one
  /// book the user has picked as their currently writable book.
  /// (Mirrors Subscription.activeBusinessBookId; kept here too so a single
  /// Book document is enough to render the book switcher badge.)
  final bool isActiveBook;
  final bool isArchived;

  // Business Profile (Business Book only) - all optional except the core
  // identity/contact fields already required above (name) or below (phone).
  final String? phone;
  final String? brandName;
  final String? shippingAddress; // null means "same as billing address"
  final String? website;
  final BankAccountDetails bankDetails;
  final String? signatureUrl;

  /// Which InvoiceTemplateStyle (see invoice_template.dart) this book's
  /// invoices render with. Null defaults to the first/classic template -
  /// see invoiceTemplateById.
  final String? invoiceTemplateId;

  Book({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.gstin,
    this.state,
    this.address,
    this.logoUrl,
    this.invoicePrefix = 'INV-{YYYY}-{0000}',
    this.resetInvoiceNumberEachFY = true,
    required this.createdAt,
    this.isActiveBook = false,
    this.isArchived = false,
    this.phone,
    this.brandName,
    this.shippingAddress,
    this.website,
    BankAccountDetails? bankDetails,
    this.signatureUrl,
    this.invoiceTemplateId,
  }) : bankDetails = bankDetails ?? BankAccountDetails();

  bool get isIndividual => type == BookType.individual;
  bool get isBusiness => type == BookType.business;

  factory Book.fromMap(String id, Map<String, dynamic> map) {
    return Book(
      id: id,
      userId: map['userId'] as String,
      type: BookType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BookType.business,
      ),
      name: map['name'] as String? ?? 'Untitled Book',
      gstin: map['gstin'] as String?,
      state: map['state'] as String?,
      address: map['address'] as String?,
      logoUrl: map['logoUrl'] as String?,
      invoicePrefix: map['invoicePrefix'] as String? ?? 'INV-{YYYY}-{0000}',
      resetInvoiceNumberEachFY: map['resetInvoiceNumberEachFY'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isActiveBook: map['isActiveBook'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      phone: map['phone'] as String?,
      brandName: map['brandName'] as String?,
      shippingAddress: map['shippingAddress'] as String?,
      website: map['website'] as String?,
      bankDetails: BankAccountDetails.fromMap(map['bankDetails'] as Map<String, dynamic>?),
      signatureUrl: map['signatureUrl'] as String?,
      invoiceTemplateId: map['invoiceTemplateId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'name': name,
        'gstin': gstin,
        'state': state,
        'address': address,
        'logoUrl': logoUrl,
        'invoicePrefix': invoicePrefix,
        'resetInvoiceNumberEachFY': resetInvoiceNumberEachFY,
        'createdAt': createdAt.toIso8601String(),
        'isActiveBook': isActiveBook,
        'isArchived': isArchived,
        'phone': phone,
        'brandName': brandName,
        'shippingAddress': shippingAddress,
        'website': website,
        'bankDetails': bankDetails.toMap(),
        'signatureUrl': signatureUrl,
      };
}
