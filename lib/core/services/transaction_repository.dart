import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import 'local_db.dart';

class TransactionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _db.collection('transactions');

  /// SRS: save must feel instant and must never be blocked by OCR/internet.
  /// Local write happens first and is what the UI reacts to; Firestore
  /// sync is fire-and-forget from here.
  Future<AppTransaction> saveTransaction({
    String? id,
    required String bookId,
    required TxType type,
    required DateTime date,
    required int amountPaise,
    int taxAmountPaise = 0,
    required String vendorOrCustomerName,
    String? contactId,
    String? categoryId,
    String? notes,
    int? businessUsePercent,
    String? taxHead,
    List<ReceiptImage> receiptImages = const [],
    bool noReceiptAvailable = false,
    String? noReceiptReason,
  }) async {
    final now = DateTime.now();
    final txId = id ?? _uuid.v4();
    final tx = AppTransaction(
      id: txId,
      bookId: bookId,
      type: type,
      date: date,
      amountPaise: amountPaise,
      taxAmountPaise: taxAmountPaise,
      vendorOrCustomerName: vendorOrCustomerName,
      contactId: contactId,
      categoryId: categoryId,
      notes: notes,
      businessUsePercent: businessUsePercent,
      taxHead: taxHead,
      financialYear: financialYearFor(date),
      receiptImages: receiptImages,
      noReceiptAvailable: noReceiptAvailable,
      noReceiptReason: noReceiptReason,
      createdAt: now,
      updatedAt: now,
      pendingSync: true,
    );

    // 1. Local write first - this is what makes Save feel instant and safe.
    await LocalDb.instance.upsertTransaction(tx);

    // 2. Background sync attempt (don't await failures, don't block UI).
    _trySyncOne(tx);

    return tx;
  }

  Future<void> _trySyncOne(AppTransaction tx) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _txCol.doc(tx.id).set(tx.toMap());
      await LocalDb.instance.markSynced(tx.id);
    } catch (_) {
      // Left as pendingSync = true; a periodic/connectivity-triggered sync
      // sweep (see syncAllPending) will retry later.
    }
  }

  /// Call this on connectivity-restored events and periodically.
  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncTransactions();
    for (final tx in pending) {
      await _trySyncOne(tx);
    }
  }

  Future<List<AppTransaction>> loadTransactions(String bookId) {
    // Local-first read: the UI always reads the local cache, which is kept
    // current by saveTransaction() and by a Firestore listener elsewhere
    // that mirrors remote changes down into LocalDb (e.g. edits made on
    // another device). Omitted here for brevity in the MVP scaffold.
    return LocalDb.instance.transactionsForBook(bookId);
  }

  Future<void> softDelete(AppTransaction tx) async {
    final updated = tx.copyWith(isDeleted: true, pendingSync: true);
    await LocalDb.instance.upsertTransaction(updated);
    _trySyncOne(updated);
  }
}
