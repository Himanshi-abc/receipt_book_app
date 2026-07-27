enum ProductItemType { product, service }

class Product {
  final String id;
  final String bookId;
  final String name;
  final ProductItemType type;

  /// The price as entered - whether it includes tax depends on
  /// [priceIncludesTax]. ALWAYS in paise, see core/utils/money.dart.
  final int sellingPricePaise;
  final bool priceIncludesTax;
  final double taxRatePercent;

  final int? purchasePricePaise;
  final String? hsnCode;
  final String? unit;

  /// Free text, not a separate entity - "select existing or create new" is
  /// handled in the UI via autocomplete over the book's already-used values.
  final String? category;

  /// Sequential per-book code assigned at creation (1, 2, 3, ...) - see
  /// ProductRepository._nextProductCode. Null only for products saved
  /// before this field existed.
  final int? productCode;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool pendingSync;

  Product({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.sellingPricePaise,
    required this.priceIncludesTax,
    required this.taxRatePercent,
    this.purchasePricePaise,
    this.hsnCode,
    this.unit,
    this.category,
    this.productCode,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.pendingSync = false,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      bookId: map['bookId'] as String,
      name: map['name'] as String? ?? '',
      type: ProductItemType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => ProductItemType.product),
      sellingPricePaise: (map['sellingPricePaise'] as num?)?.toInt() ?? 0,
      priceIncludesTax: map['priceIncludesTax'] as bool? ?? false,
      taxRatePercent: (map['taxRatePercent'] as num?)?.toDouble() ?? 0,
      purchasePricePaise: (map['purchasePricePaise'] as num?)?.toInt(),
      hsnCode: map['hsnCode'] as String?,
      unit: map['unit'] as String?,
      category: map['category'] as String?,
      productCode: (map['productCode'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      pendingSync: map['pendingSync'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'type': type.name,
        'sellingPricePaise': sellingPricePaise,
        'priceIncludesTax': priceIncludesTax,
        'taxRatePercent': taxRatePercent,
        'purchasePricePaise': purchasePricePaise,
        'hsnCode': hsnCode,
        'unit': unit,
        'category': category,
        'productCode': productCode,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  Product copyWith({
    String? name,
    ProductItemType? type,
    int? sellingPricePaise,
    bool? priceIncludesTax,
    double? taxRatePercent,
    int? purchasePricePaise,
    String? hsnCode,
    String? unit,
    String? category,
    int? productCode,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? pendingSync,
  }) {
    return Product(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      sellingPricePaise: sellingPricePaise ?? this.sellingPricePaise,
      priceIncludesTax: priceIncludesTax ?? this.priceIncludesTax,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      purchasePricePaise: purchasePricePaise ?? this.purchasePricePaise,
      hsnCode: hsnCode ?? this.hsnCode,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      productCode: productCode ?? this.productCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDeleted: isDeleted ?? this.isDeleted,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
