enum ContactType { vendor, customer }

class Contact {
  final String id;
  final String bookId;
  final String name;
  final String? phone;
  final String? gstin;
  final String? address;
  final ContactType type;

  final DateTime updatedAt;
  final bool isDeleted;

  /// True while this contact exists only in local (offline) storage and
  /// hasn't been synced to the backend yet - same offline-first convention
  /// as AppTransaction.pendingSync.
  final bool pendingSync;

  Contact({
    required this.id,
    required this.bookId,
    required this.name,
    this.phone,
    this.gstin,
    this.address,
    required this.type,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.pendingSync = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory Contact.fromMap(String id, Map<String, dynamic> map) => Contact(
        id: id,
        bookId: map['bookId'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String?,
        gstin: map['gstin'] as String?,
        address: map['address'] as String?,
        type: ContactType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => ContactType.vendor),
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        isDeleted: map['isDeleted'] as bool? ?? false,
        pendingSync: map['pendingSync'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'phone': phone,
        'gstin': gstin,
        'address': address,
        'type': type.name,
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  Contact copyWith({
    String? name,
    String? phone,
    String? gstin,
    String? address,
    ContactType? type,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? pendingSync,
  }) {
    return Contact(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      type: type ?? this.type,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
