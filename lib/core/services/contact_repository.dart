import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';
import 'local_db.dart';

/// Local-first, same pattern as TransactionRepository: local write happens
/// first and is what the UI reacts to, Firestore sync is fire-and-forget.
class ContactRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _contacts => _db.collection('contacts');

  Future<Contact> saveContact({
    String? id,
    required String bookId,
    required String name,
    String? phone,
    String? gstin,
    String? address,
    required ContactType type,
  }) async {
    final contact = Contact(
      id: id ?? _uuid.v4(),
      bookId: bookId,
      name: name,
      phone: phone,
      gstin: gstin,
      address: address,
      type: type,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );

    await LocalDb.instance.upsertContact(contact);
    _trySyncOne(contact);
    return contact;
  }

  Future<void> _trySyncOne(Contact c) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      await _contacts.doc(c.id).set(c.toMap());
      await LocalDb.instance.markContactSynced(c.id);
    } catch (_) {
      // Left as pendingSync = true; retried on next save / sync sweep.
    }
  }

  Future<void> syncAllPending() async {
    final pending = await LocalDb.instance.pendingSyncContacts();
    for (final c in pending) {
      await _trySyncOne(c);
    }
  }

  Future<List<Contact>> loadContacts(String bookId, {ContactType? type}) {
    return LocalDb.instance.contactsForBook(bookId, type: type);
  }

  Future<void> softDelete(Contact c) async {
    final updated = c.copyWith(isDeleted: true, pendingSync: true);
    await LocalDb.instance.upsertContact(updated);
    _trySyncOne(updated);
  }
}
