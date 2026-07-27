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

  /// Per-book Product Code: the smallest number starting from 1 that isn't
  /// already used by an active (non-deleted) product. Deliberately not a
  /// monotonically-increasing counter - that would never let a deleted
  /// product's code be reused. LocalDb.productsForBook already excludes
  /// soft-deleted products, so a freed code shows up as available again as
  /// soon as its product is deleted.
  Future<int> _nextProductCode(String bookId) async {
    final products = await LocalDb.instance.productsForBook(bookId);
    final usedCodes = products.map((p) => p.productCode).whereType<int>().toSet();
    var candidate = 1;
    while (usedCodes.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

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
    int? productCode,
  }) async {
    final now = DateTime.now();
    // Only ever assigned once, when the product is first created - editing
    // an existing product (id already set) always carries its code forward
    // via the productCode param the caller passes back in.
    final isNew = id == null;
    final code = isNew ? (productCode ?? await _nextProductCode(bookId)) : productCode;
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
      productCode: code,
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
