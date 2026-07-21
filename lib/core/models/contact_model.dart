enum ContactType { vendor, customer }

class Contact {
  final String id;
  final String bookId;
  final String name;
  final String? phone;
  final String? gstin;
  final ContactType type;

  Contact({
    required this.id,
    required this.bookId,
    required this.name,
    this.phone,
    this.gstin,
    required this.type,
  });

  factory Contact.fromMap(String id, Map<String, dynamic> map) => Contact(
        id: id,
        bookId: map['bookId'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String?,
        gstin: map['gstin'] as String?,
        type: ContactType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => ContactType.vendor),
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'phone': phone,
        'gstin': gstin,
        'type': type.name,
      };
}
