/// Categories for Products/Services (a Business Book's product catalog).
/// Deliberately a separate entity from [Category] (Income/Expense
/// transaction categories) - the two domains must never mix.
class ProductCategory {
  final String id;
  final String bookId;
  final String name;
  final DateTime? createdAt;
  final bool isDeleted;
  final bool pendingSync;

  ProductCategory({
    required this.id,
    required this.bookId,
    required this.name,
    this.createdAt,
    this.isDeleted = false,
    this.pendingSync = false,
  });

  factory ProductCategory.fromMap(String id, Map<String, dynamic> map) => ProductCategory(
        id: id,
        bookId: map['bookId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
        isDeleted: map['isDeleted'] as bool? ?? false,
        pendingSync: map['pendingSync'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  ProductCategory copyWith({bool? isDeleted, bool? pendingSync}) => ProductCategory(
        id: id,
        bookId: bookId,
        name: name,
        createdAt: createdAt,
        isDeleted: isDeleted ?? this.isDeleted,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  // Same rationale as Category: DropdownButtonFormField matches items by ==,
  // so two instances representing the same row must compare equal by id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCategory && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
