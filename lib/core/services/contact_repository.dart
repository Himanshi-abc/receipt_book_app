import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';

class ContactRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _contacts => _db.collection('contacts');

  Stream<List<Contact>> watchContacts(String bookId, {ContactType? type}) {
    Query<Map<String, dynamic>> q = _contacts.where('bookId', isEqualTo: bookId);
    if (type != null) q = q.where('type', isEqualTo: type.name);
    return q.snapshots().map(
        (snap) => snap.docs.map((d) => Contact.fromMap(d.id, d.data())).toList());
  }

  Future<Contact> createContact({
    required String bookId,
    required String name,
    String? phone,
    String? gstin,
    required ContactType type,
  }) async {
    final id = _uuid.v4();
    final contact = Contact(
      id: id,
      bookId: bookId,
      name: name,
      phone: phone,
      gstin: gstin,
      type: type,
    );
    await _contacts.doc(id).set(contact.toMap());
    return contact;
  }
}
