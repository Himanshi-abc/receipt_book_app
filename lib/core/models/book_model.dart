enum BookType { individual, business }

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
  });

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
      };
}
