import 'package:flutter/foundation.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/subscription_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/services/book_repository.dart';
import '../../../core/services/category_repository.dart';
import '../../../core/services/contact_repository.dart';
import '../../../l10n/app_localizations.dart';

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

  /// [l10n] names the seeded default contacts and category. These are
  /// ordinary editable records, not fixed system rows, so they're written
  /// once in whatever language the user created the book in and can be
  /// renamed afterwards like any other contact.
  Future<Book> createBusinessBook({
    required String userId,
    required String name,
    String? gstin,
    required String state,
    String? address,
    required AppLocalizations l10n,
  }) async {
    final book = await _repo.createBusinessBook(
        userId: userId, name: name, gstin: gstin, state: state, address: address);
    await _seedBusinessBookDefaults(book, l10n);
    return book;
  }

  /// Product decision: every new Business Book starts with two default
  /// Customer contacts - "Daily Counter" (a catch-all party for walk-in /
  /// cash sales that don't warrant creating a real contact) and "Default
  /// Customer" (a generic fallback so a bill is never blocked on picking a
  /// party) - plus one default Income category, also "Daily Counter", for
  /// quick day-to-day sales entry. Business Book Income otherwise has no
  /// built-in categories at all.
  ///
  /// The contact and the category sharing the name "Daily Counter" is
  /// intentional, not a collision - a user billing to that customer while
  /// categorising the matching ledger entry under the same name is exactly
  /// the point.
  Future<void> _seedBusinessBookDefaults(
    Book book,
    AppLocalizations l10n,
  ) async {
    final contactRepo = ContactRepository();
    for (final name in [l10n.defaultContactDailyCounter, l10n.defaultContactCustomer]) {
      await contactRepo.saveContact(
        bookId: book.id,
        name: name,
        type: ContactType.customer,
      );
    }
    await CategoryRepository().createCategory(
      bookId: book.id,
      name: l10n.defaultContactDailyCounter,
      type: TxType.income,
    );
  }

  Future<void> setActiveBusinessBook(String userId, String bookId) =>
      _repo.setActiveBusinessBook(userId, bookId);

  /// Business Profile edits - see BookRepository.updateBook. `currentBook`
  /// refreshes on its own once the write flows back through the
  /// watchBooks() stream in listenToUser, no manual patch needed here.
  Future<void> updateBook(String bookId, Map<String, dynamic> patch) =>
      _repo.updateBook(bookId, patch);

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
