import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/product_category_model.dart';
import 'local_db.dart';

/// User-created Product/Service categories. Kept entirely separate from
/// [CategoryRepository] (Income/Expense transaction categories) - same
/// local-first + background-sync pattern as the rest of the app.
class ProductCategoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _productCategoriesCol =>
      _db.collection('productCategories');

  Future<ProductCategory> createCategory({
    required String bookId,
    required String name,
  }) async {
    final category = ProductCategory(
      id: _uuid.v4(),
      bookId: bookId,
      name: name,
      createdAt: DateTime.now(),
      pendingSync: true,
    );

    await LocalDb.instance.upsertProductCategory(category);
    _trySyncOne(category);

    return category;
  }

  Future<void> _trySyncOne(ProductCategory c) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _productCategoriesCol.doc(c.id).set(c.toMap());
      await LocalDb.instance.markProductCategorySynced(c.id);
    } catch (_) {
      // Left as pendingSync = true; retried by syncAllPending.
    }
  }

  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncProductCategories();
    for (final c in pending) {
      await _trySyncOne(c);
    }
  }

  Future<List<ProductCategory>> loadCategories(String bookId) {
    return LocalDb.instance.productCategoriesForBook(bookId);
  }
}
