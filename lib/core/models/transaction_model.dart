enum TxType { income, expense }

class ReceiptImage {
  final String imageUrl;
  final DateTime uploadedAt;
  final String? localPath; // set while offline, before it's synced/uploaded

  ReceiptImage({required this.imageUrl, required this.uploadedAt, this.localPath});

  factory ReceiptImage.fromMap(Map<String, dynamic> map) => ReceiptImage(
        imageUrl: map['imageUrl'] as String? ?? '',
        uploadedAt: DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ??
            DateTime.now(),
        localPath: map['localPath'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'imageUrl': imageUrl,
        'uploadedAt': uploadedAt.toIso8601String(),
        'localPath': localPath,
      };
}

class AppTransaction {
  final String id;
  final String bookId;
  final TxType type;
  final DateTime date;

  /// ALWAYS in paise. See core/utils/money.dart - never store a double here.
  final int amountPaise;
  final int taxAmountPaise;

  final String vendorOrCustomerName;
  final String? contactId;
  final String? categoryId;
  final String? notes;

  /// e.g. 70 means 70% business use, 30% personal (Business Book only).
  final int? businessUsePercent;

  /// Individual Book only: Salary / Business Income / Other Sources /
  /// House Property, or a deduction type like 80C/80D/80G.
  final String? taxHead;

  final String financialYear; // e.g. "2026-27"

  /// SRS Section 8: a transaction always needs a receipt photo, unless the
  /// user explicitly checks "no receipt" and gives a reason.
  final List<ReceiptImage> receiptImages;
  final bool noReceiptAvailable;
  final String? noReceiptReason;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  /// True while this transaction exists only in local (offline) storage and
  /// hasn't been synced to the backend yet. Never surfaced to the user as
  /// an error - saving must never be blocked by connectivity.
  final bool pendingSync;

  AppTransaction({
    required this.id,
    required this.bookId,
    required this.type,
    required this.date,
    required this.amountPaise,
    this.taxAmountPaise = 0,
    required this.vendorOrCustomerName,
    this.contactId,
    this.categoryId,
    this.notes,
    this.businessUsePercent,
    this.taxHead,
    required this.financialYear,
    this.receiptImages = const [],
    this.noReceiptAvailable = false,
    this.noReceiptReason,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.pendingSync = false,
  });

  /// SRS Section 8 rule: mandatory unless explicitly waived with a reason.
  bool get hasValidReceiptState =>
      receiptImages.isNotEmpty ||
      (noReceiptAvailable &&
          (noReceiptReason != null && noReceiptReason!.trim().isNotEmpty));

  factory AppTransaction.fromMap(String id, Map<String, dynamic> map) {
    return AppTransaction(
      id: id,
      bookId: map['bookId'] as String,
      type: TxType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => TxType.expense),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 0,
      taxAmountPaise: (map['taxAmountPaise'] as num?)?.toInt() ?? 0,
      vendorOrCustomerName: map['vendorOrCustomerName'] as String? ?? '',
      contactId: map['contactId'] as String?,
      categoryId: map['categoryId'] as String?,
      notes: map['notes'] as String?,
      businessUsePercent: (map['businessUsePercent'] as num?)?.toInt(),
      taxHead: map['taxHead'] as String?,
      financialYear: map['financialYear'] as String? ?? '',
      receiptImages: ((map['receiptImages'] as List?) ?? [])
          .map((e) => ReceiptImage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      noReceiptAvailable: map['noReceiptAvailable'] as bool? ?? false,
      noReceiptReason: map['noReceiptReason'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      pendingSync: map['pendingSync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'type': type.name,
        'date': date.toIso8601String(),
        'amountPaise': amountPaise,
        'taxAmountPaise': taxAmountPaise,
        'vendorOrCustomerName': vendorOrCustomerName,
        'contactId': contactId,
        'categoryId': categoryId,
        'notes': notes,
        'businessUsePercent': businessUsePercent,
        'taxHead': taxHead,
        'financialYear': financialYear,
        'receiptImages': receiptImages.map((e) => e.toMap()).toList(),
        'noReceiptAvailable': noReceiptAvailable,
        'noReceiptReason': noReceiptReason,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  AppTransaction copyWith({
    TxType? type,
    DateTime? date,
    int? amountPaise,
    int? taxAmountPaise,
    String? vendorOrCustomerName,
    String? contactId,
    String? categoryId,
    String? notes,
    int? businessUsePercent,
    String? taxHead,
    List<ReceiptImage>? receiptImages,
    bool? noReceiptAvailable,
    String? noReceiptReason,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? pendingSync,
  }) {
    return AppTransaction(
      id: id,
      bookId: bookId,
      type: type ?? this.type,
      date: date ?? this.date,
      amountPaise: amountPaise ?? this.amountPaise,
      taxAmountPaise: taxAmountPaise ?? this.taxAmountPaise,
      vendorOrCustomerName: vendorOrCustomerName ?? this.vendorOrCustomerName,
      contactId: contactId ?? this.contactId,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      businessUsePercent: businessUsePercent ?? this.businessUsePercent,
      taxHead: taxHead ?? this.taxHead,
      financialYear: financialYear,
      receiptImages: receiptImages ?? this.receiptImages,
      noReceiptAvailable: noReceiptAvailable ?? this.noReceiptAvailable,
      noReceiptReason: noReceiptReason ?? this.noReceiptReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}

/// e.g. new Date(2026, 6, 19) -> "2026-27" (Indian financial year: Apr-Mar)
String financialYearFor(DateTime date) {
  final year = date.year;
  if (date.month >= 4) {
    return '$year-${(year + 1).toString().substring(2)}';
  } else {
    return '${year - 1}-${year.toString().substring(2)}';
  }
}
