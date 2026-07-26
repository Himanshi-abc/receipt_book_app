import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/local_db.dart';

/// Local-first, same pattern as TransactionRepository/ContactRepository:
/// local write happens first and is what the UI reacts to, Firestore sync
/// is fire-and-forget.
class ProductRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');

  Future<Product> saveProduct({
    String? id,
    DateTime? createdAt,
    required String bookId,
    required String name,
    required ProductItemType type,
    required int sellingPricePaise,
    required bool priceIncludesTax,
    required double taxRatePercent,
    int? purchasePricePaise,
    String? hsnCode,
    String? unit,
    String? category,
  }) async {
    final now = DateTime.now();
    final product = Product(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      name: name,
      type: type,
      sellingPricePaise: sellingPricePaise,
      priceIncludesTax: priceIncludesTax,
      taxRatePercent: taxRatePercent,
      purchasePricePaise: purchasePricePaise,
      hsnCode: hsnCode,
      unit: unit,
      category: category,
      createdAt: createdAt ?? now,
      updatedAt: now,
      pendingSync: true,
    );

    await LocalDb.instance.upsertProduct(product);
    _trySyncOne(product);
    return product;
  }

  Future<void> _trySyncOne(Product p) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _products.doc(p.id).set(p.toMap());
      await LocalDb.instance.markProductSynced(p.id);
    } catch (_) {
      // Left as pendingSync = true; retried on next save / sync sweep.
    }
  }

  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncProducts();
    for (final p in pending) {
      await _trySyncOne(p);
    }
  }

  Future<List<Product>> loadProducts(String bookId) {
    return LocalDb.instance.productsForBook(bookId);
  }

  Future<void> softDelete(Product p) async {
    final updated = p.copyWith(isDeleted: true, pendingSync: true);
    await LocalDb.instance.upsertProduct(updated);
    _trySyncOne(updated);
  }
}
