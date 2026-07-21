import 'transaction_model.dart';

class Category {
  final String id;
  final String? bookId; // null if system default
  final String name;
  final TxType type;

  Category({required this.id, this.bookId, required this.name, required this.type});

  // Flutter's DropdownButtonFormField matches the selected value against
  // its items list by ==. Category.systemDefaults() and any Firestore-backed
  // list build fresh instances on every call/rebuild, so without this
  // override two Categories with the same id would be considered different
  // objects and the dropdown would throw "should be exactly one item with
  // [DropdownButton]'s value" as soon as the list was rebuilt after a
  // selection.
  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        bookId: map['bookId'] as String?,
        name: map['name'] as String? ?? '',
        type: TxType.values.firstWhere((e) => e.name == map['type'],
            orElse: () => TxType.expense),
      );

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'name': name,
        'type': type.name,
      };

  /// System defaults shown before any custom categories are loaded.
  /// SRS 3: "Rent, Travel, Office Supplies, Sales, Salary Income" etc.
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
}
