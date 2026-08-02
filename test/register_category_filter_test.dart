import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/models/category_model.dart';
import 'package:receipt_book/core/models/transaction_model.dart';
import 'package:receipt_book/features/ledger/screens/register_section_body.dart';

/// The Register section's "Categories" filter.
///
/// Regression coverage for the bug: the filter built its options from
/// Category.defaultsFor(isBusiness) - a hardcoded system list - instead of
/// the categories actually saved for the open book. For a Business Book
/// that meant the dropdown offered categories ("Sales", "Rent", ...) that
/// may never have been created in this book, while the categories the user
/// really did create (real Firestore ids, never matching the sys_* ids the
/// defaults use) never appeared and their names couldn't be looked up
/// either. registerCategoryOptions is the extracted fix.
void main() {
  Category cat(String id, String name, TxType type) =>
      Category(id: id, bookId: 'book-1', name: name, type: type);

  group('registerCategoryOptions', () {
    test('Business Book gets only the book\'s own categories - no system defaults', () {
      final own = [
        cat('c1', 'Freight', TxType.expense),
        cat('c2', 'Consulting Income', TxType.income),
      ];

      final options = registerCategoryOptions(isBusiness: true, ownCategories: own);

      expect(options, containsAll(own));
      expect(options.length, own.length);
      // None of the hardcoded system defaults ("Sales", "Rent", ...) leak
      // in just because this is a Business Book.
      expect(options.any((c) => c.id.startsWith('sys_')), isFalse);
    });

    test('an empty Business Book (no categories created yet) offers nothing', () {
      final options = registerCategoryOptions(isBusiness: true, ownCategories: const []);
      expect(options, isEmpty);
    });

    test('Individual Book gets the fixed defaults plus its own categories', () {
      final own = [cat('c1', 'Side Gig', TxType.income)];

      final options = registerCategoryOptions(isBusiness: false, ownCategories: own);

      expect(options, containsAll(own));
      expect(
        options.any((c) => c.id == 'ind_rent'),
        isTrue,
        reason: 'Individual Book keeps its fixed default list',
      );
    });

    test('a real saved category can be looked up by id, unlike before the fix', () {
      // Real categories carry a Firestore-generated uuid, never a sys_*/
      // ind_* id - this is exactly the id a saved AppTransaction.categoryId
      // would carry, and exactly what used to fail to match.
      final saved = cat('9f2c-real-uuid', 'Equipment Rental', TxType.expense);

      final options = registerCategoryOptions(
        isBusiness: true,
        ownCategories: [saved],
      );

      expect(
        options.where((c) => c.id == '9f2c-real-uuid').single.name,
        'Equipment Rental',
      );
    });
  });
}
