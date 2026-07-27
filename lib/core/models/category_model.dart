import 'transaction_model.dart';

class Category {
  final String id;
  final String? bookId; // null if system default
  final String name;
  final TxType type;
  final DateTime? createdAt;
  final bool isDeleted;
  final bool pendingSync;

  Category({
    required this.id,
    this.bookId,
    required this.name,
    required this.type,
    this.createdAt,
    this.isDeleted = false,
    this.pendingSync = false,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        bookId: map['bookId'] as String?,
        name: map['name'] as String? ?? '',
        type: TxType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => TxType.expense),
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
        isDeleted: map['isDeleted'] as bool? ?? false,
        pendingSync: map['pendingSync'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'type': type.name,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'isDeleted': isDeleted,
        'pendingSync': pendingSync,
      };

  Category copyWith({bool? isDeleted, bool? pendingSync}) => Category(
        id: id,
        bookId: bookId,
        name: name,
        type: type,
        createdAt: createdAt,
        isDeleted: isDeleted ?? this.isDeleted,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  /// System defaults shown before any custom categories are loaded.
  /// SRS 3: "Rent, Travel, Office Supplies, Sales, Salary Income" etc.
  /// Business Book only - see [individualDefaults] for the Individual Book.
  static List<Category> systemDefaults() => [
        Category(id: 'sys_sales', name: 'Sales', type: TxType.income),
        Category(id: 'sys_salary_income', name: 'Salary Income', type: TxType.income),
        Category(id: 'sys_other_income', name: 'Other Income', type: TxType.income),
        Category(id: 'sys_rent', name: 'Rent', type: TxType.expense),
        Category(id: 'sys_travel', name: 'Travel', type: TxType.expense),
        Category(id: 'sys_office_supplies', name: 'Office Supplies', type: TxType.expense),
        Category(id: 'sys_utilities', name: 'Utilities', type: TxType.expense),
        Category(id: 'sys_salary_paid', name: 'Salary Paid', type: TxType.expense),
        Category(id: 'sys_misc', name: 'Miscellaneous', type: TxType.expense),
      ];

  /// Individual Book categories: no "Sales" (that's a business concept),
  /// and a fixed 7-category expense list instead of the business one.
  static List<Category> individualDefaults() => [
        Category(id: 'sys_salary_income', name: 'Salary Income', type: TxType.income),
        Category(id: 'sys_other_income', name: 'Other Income', type: TxType.income),
        Category(id: 'ind_rent', name: 'Rent', type: TxType.expense),
        Category(id: 'ind_travel', name: 'Travel', type: TxType.expense),
        Category(id: 'ind_family_education', name: 'Family & Education', type: TxType.expense),
        Category(id: 'ind_insurance_health', name: 'Insurance & Health', type: TxType.expense),
        Category(id: 'ind_savings_investments', name: 'Savings & Investments', type: TxType.expense),
        Category(id: 'ind_donations', name: 'Donations', type: TxType.expense),
        Category(id: 'ind_other', name: 'Other', type: TxType.expense),
      ];

  static List<Category> defaultsFor(bool isBusiness) =>
      isBusiness ? systemDefaults() : individualDefaults();

  // Dropdown widgets match the selected value against the items list by ==;
  // system-default lists build fresh Category instances on every rebuild,
  // so without this override two Categories with the same id would be
  // considered different objects and DropdownButtonFormField would throw.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
