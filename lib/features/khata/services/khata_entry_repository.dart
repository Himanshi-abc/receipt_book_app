import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/services/local_db.dart';

/// Local-first, same pattern as TransactionRepository: local write happens
/// first and is what the UI reacts to, Firestore sync is fire-and-forget.
class KhataEntryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('khata_entries');

  Future<KhataEntry> saveEntry({
    String? id,
    DateTime? createdAt,
    required String bookId,
    required String contactId,
    required KhataEntryType type,
    required int amountPaise,
    String? description,
    required DateTime date,
    List<KhataAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final entry = KhataEntry(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      contactId: contactId,
      type: type,
      amountPaise: amountPaise,
      description: description,
      date: date,
      attachments: attachments,
      createdAt: createdAt ?? now,
      updatedAt: now,
      pendingSync: true,
    );

    // 1. Local write first - this is what makes Save feel instant and safe,
    // never blocked by connectivity (same rule as transactions).
    await LocalDb.instance.upsertKhataEntry(entry);

    // 2. Background sync attempt (don't await failures, don't block UI).
    _trySyncOne(entry);

    return entry;
  }

  Future<void> _trySyncOne(KhataEntry e) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _col.doc(e.id).set(e.toMap());
      await LocalDb.instance.markKhataEntrySynced(e.id);
    } catch (_) {
      // Left as pendingSync = true; retried on next save / sync sweep.
    }
  }

  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncKhataEntries();
    for (final e in pending) {
      await _trySyncOne(e);
    }
  }

  Future<List<KhataEntry>> entriesForContact(String contactId) {
    return LocalDb.instance.khataEntriesForContact(contactId);
  }

  Future<List<KhataEntry>> entriesForBook(String bookId) {
    return LocalDb.instance.khataEntriesForBook(bookId);
  }

  Future<void> softDelete(KhataEntry e) async {
    final updated = e.copyWith(isDeleted: true, pendingSync: true);
    await LocalDb.instance.upsertKhataEntry(updated);
    _trySyncOne(updated);
  }
}
