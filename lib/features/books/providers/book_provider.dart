import 'package:flutter/foundation.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/subscription_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/services/book_repository.dart';

class BookProvider extends ChangeNotifier {
  final BookRepository _repo = BookRepository();

  List<Book> _books = [];
  List<Book> get books => _books;

  Subscription? _subscription;
  Subscription? get subscription => _subscription;

  Book? _currentBook;
  Book? get currentBook => _currentBook;

  bool _loading = true;
  bool get loading => _loading;

  void listenToUser(String userId) {
    _repo.watchBooks(userId).listen((books) {
      _books = books;
      // Keep currentBook pointer fresh, default to Individual Book first run.
      if (_currentBook == null && books.isNotEmpty) {
        _currentBook = books.firstWhere((b) => b.isIndividual, orElse: () => books.first);
      } else if (_currentBook != null) {
        final match = books.where((b) => b.id == _currentBook!.id);
        if (match.isNotEmpty) _currentBook = match.first;
      }
      _loading = false;
      notifyListeners();
    });

    _repo.watchSubscription(userId).listen((sub) {
      _subscription = sub ?? Subscription.none(userId);
      notifyListeners();
    });
  }

  void switchBook(Book book) {
    _currentBook = book;
    notifyListeners();
  }

  Future<Book> createIndividualBookIfNeeded(String userId) =>
      _repo.createIndividualBookIfNeeded(userId);

  Future<Book> createBusinessBook({
    required String userId,
    required String name,
    String? gstin,
    required String state,
    String? address,
  }) =>
      _repo.createBusinessBook(
          userId: userId, name: name, gstin: gstin, state: state, address: address);

  Future<void> setActiveBusinessBook(String userId, String bookId) =>
      _repo.setActiveBusinessBook(userId, bookId);

  Future<void> choosePlan({
    required String userId,
    required PlanType planType,
    required BillingCycle billingCycle,
  }) =>
      _repo.choosePlan(userId: userId, planType: planType, billingCycle: billingCycle);

  /// The single shared check, exposed for every screen that gates writes.
  BookAccessResult accessFor(Book book) {
    if (_subscription == null) {
      return const BookAccessResult(false, LockReason.noSubscription);
    }
    return BookAccessService.check(book, _subscription!);
  }

  bool get currentBookIsWritable =>
      _currentBook == null ? false : accessFor(_currentBook!).writable;
}
