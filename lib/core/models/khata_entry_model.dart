enum KhataEntryType { youGave, youGot }

/// A file attached to a khata ledger entry. Same shape/semantics as
/// ReceiptImage in transaction_model.dart (see that file for why the
/// localPath/fileName fields exist - offline-first save, generic file
/// support, not just camera photos).
class KhataAttachment {
  final String url;
  final DateTime uploadedAt;
  final String? localPath;
  final String? fileName;

  KhataAttachment({
    required this.url,
    required this.uploadedAt,
    this.localPath,
    this.fileName,
  });

  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'];

  bool get isImageFile {
    final name = (fileName ?? localPath ?? url).toLowerCase();
    return _imageExtensions.any((ext) => name.endsWith(ext));
  }

  factory KhataAttachment.fromMap(Map<String, dynamic> map) => KhataAttachment(
        url: map['url'] as String? ?? '',
        uploadedAt: DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
        localPath: map['localPath'] as String?,
        fileName: map['fileName'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'uploadedAt': uploadedAt.toIso8601String(),
        'localPath': localPath,
        'fileName': fileName,
      };
}

/// A single "You Gave" / "You Got" entry against a customer or supplier.
/// Outstanding balance per party is never stored here - it's computed on
/// the fly from all of a contact's entries (see khata_balance.dart).
class KhataEntry {
  final String id;
  final String bookId;
  final String contactId;
  final KhataEntryType type;

  /// ALWAYS in paise. See core/utils/money.dart - never store a double here.
  final int amountPaise;

  final String? description;
  final DateTime date;
  final List<KhataAttachment> attachments;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool pendingSync;

  KhataEntry({
    required this.id,
    required this.bookId,
    required this.contactId,
    required this.type,
    required this.amountPaise,
    this.description,
    required this.date,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.pendingSync = false,
  });

  factory KhataEntry.fromMap(String id, Map<String, dynamic> map) {
    return KhataEntry(
      id: id,
      bookId: map['bookId'] as String,
      contactId: map['contactId'] as String,
      type: KhataEntryType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => KhataEntryType.youGave),
      amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 0,
      description: map['description'] as String?,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      attachments: ((map['attachments'] as List?) ?? [])
          .map((e) => KhataAttachment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      pendingSync: map['pendingSync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'contactId': contactId,
        'type': type.name,
        'amountPaise': amountPaise,
        'description': description,
        'date': date.toIso8601String(),
        'attachments': attachments.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  KhataEntry copyWith({
    int? amountPaise,
    String? description,
    DateTime? date,
    List<KhataAttachment>? attachments,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? pendingSync,
  }) {
    return KhataEntry(
      id: id,
      bookId: bookId,
      contactId: contactId,
      type: type,
      amountPaise: amountPaise ?? this.amountPaise,
      description: description ?? this.description,
      date: date ?? this.date,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
