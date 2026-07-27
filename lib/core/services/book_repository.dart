import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/book_model.dart';
import '../models/subscription_model.dart';

class BookRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _books => _db.collection('books');
  DocumentReference<Map<String, dynamic>> _subDoc(String userId) =>
      _db.collection('subscriptions').doc(userId);

  /// SRS 4.1: "On first login, app auto-creates the user's Individual Book."
  Future<Book> createIndividualBookIfNeeded(String userId) async {
    final existing = await _books
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: BookType.individual.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return Book.fromMap(existing.docs.first.id, existing.docs.first.data());
    }
    final id = _uuid.v4();
    final book = Book(
      id: id,
      userId: userId,
      type: BookType.individual,
      name: 'My Individual Book',
      createdAt: DateTime.now(),
    );
    await _books.doc(id).set(book.toMap());
    return book;
  }

  /// SRS 5.1: "the very first Business Book a user creates starts the
  /// account's 1-month trial (trial_start_date = now on the
  /// User/Subscription record, not per book). Any additional Business
  /// Books created during the trial just attach to the same trial."
  Future<Book> createBusinessBook({
    required String userId,
    required String name,
    String? gstin,
    required String state,
    String? address,
  }) async {
    final id = _uuid.v4();
    final book = Book(
      id: id,
      userId: userId,
      type: BookType.business,
      name: name,
      gstin: gstin,
      state: state,
      address: address,
      createdAt: DateTime.now(),
    );
    await _books.doc(id).set(book.toMap());
    await _startTrialIfFirstBusinessBook(userId);
    return book;
  }

  Future<void> _startTrialIfFirstBusinessBook(String userId) async {
    final subSnap = await _subDoc(userId).get();
    if (subSnap.exists) return; // trial (or a plan) already started

    final now = DateTime.now();
    final sub = Subscription(
      userId: userId,
      planType: PlanType.trial,
      status: SubscriptionStatus.trial,
      trialStartDate: now,
      trialEndDate: now.add(const Duration(days: 30)),
    );
    await _subDoc(userId).set(sub.toMap());
  }

  Stream<List<Book>> watchBooks(String userId) {
    return _books
        .where('userId', isEqualTo: userId)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList());
  }

  Stream<Subscription?> watchSubscription(String userId) {
    return _subDoc(userId).snapshots().map(
        (snap) => snap.exists ? Subscription.fromMap(userId, snap.data()!) : null);
  }

  /// SRS 5.1: required "Choose your active Business Book" screen when
  /// trial ends and user picks (or defaults to) Single Book Plan.
  Future<void> setActiveBusinessBook(String userId, String bookId) async {
    await _subDoc(userId).update({'activeBusinessBookId': bookId});
  }

  Future<void> choosePlan({
    required String userId,
    required PlanType planType,
    required BillingCycle billingCycle,
  }) async {
    await _subDoc(userId).update({
      'planType': planType.name,
      'status': SubscriptionStatus.active.name,
      'billingCycle': billingCycle.name,
      // subscriptionExpiryDate would be set from the platform billing
      // webhook/receipt validation in a real integration.
    });
  }

  Future<void> archiveBook(String bookId) async {
    await _books.doc(bookId).update({'isArchived': true});
  }

  /// Business Profile edits (name, GSTIN, phone, branding, addresses, bank
  /// details, signature, etc.) - a plain partial update, same pattern as
  /// [archiveBook]. [patch] should only contain the fields being changed.
  Future<void> updateBook(String bookId, Map<String, dynamic> patch) async {
    await _books.doc(bookId).update(patch);
  }
}
