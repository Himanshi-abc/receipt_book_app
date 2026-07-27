import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import 'local_db.dart';

/// User-created categories, on top of [Category.systemDefaults] /
/// [Category.individualDefaults]. Same local-first + background-sync
/// pattern as [TransactionRepository].
class CategoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _categoriesCol =>
      _db.collection('categories');

  Future<Category> createCategory({
    required String bookId,
    required String name,
    required TxType type,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      bookId: bookId,
      name: name,
      type: type,
      createdAt: DateTime.now(),
      pendingSync: true,
    );

    await LocalDb.instance.upsertCategory(category);
    _trySyncOne(category);

    return category;
  }

  Future<void> _trySyncOne(Category c) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _categoriesCol.doc(c.id).set(c.toMap());
      await LocalDb.instance.markCategorySynced(c.id);
    } catch (_) {
      // Left as pendingSync = true; retried by syncAllPending.
    }
  }

  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncCategories();
    for (final c in pending) {
      await _trySyncOne(c);
    }
  }

  Future<List<Category>> loadCategories(String bookId) {
    return LocalDb.instance.categoriesForBook(bookId);
  }
}
