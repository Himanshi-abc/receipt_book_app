import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../models/book_model.dart';
import '../services/book_access_service.dart';
import '../../features/books/providers/book_provider.dart';

class BookSwitcher extends StatelessWidget {
  const BookSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final current = bookProvider.currentBook;

    return InkWell(
      onTap: () => _openSwitcher(context, bookProvider),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(current?.isIndividual == true ? Icons.person : Icons.storefront, size: 20),
          const SizedBox(width: 6),
          Text(
            current?.name ?? AppLocalizations.of(context).selectABook,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  void _openSwitcher(BuildContext context, BookProvider bookProvider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.switchBook,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...bookProvider.books.map((book) {
                final access = bookProvider.accessFor(book);
                return ListTile(
                  leading: Icon(book.isIndividual ? Icons.person : Icons.storefront),
                  title: Text(book.name),
                  subtitle: Text(_statusLabel(l10n, book, access, bookProvider)),
                  trailing: book.id == bookProvider.currentBook?.id
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    bookProvider.switchBook(book);
                    Navigator.pop(ctx);
                  },
                );
              }),
              ListTile(
                leading: const Icon(Icons.add_business),
                title: Text(l10n.addBusinessBook),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/add-business-book');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(
    AppLocalizations l10n,
    Book book,
    BookAccessResult access,
    BookProvider bookProvider,
  ) {
    if (book.isIndividual) return l10n.bookStatusAlwaysFree;
    if (access.writable) {
      final sub = bookProvider.subscription;
      // trialDaysLeft is nullable (no trial end date on record); fall back
      // to the plain "Active" caption rather than printing "null days".
      final daysLeft = sub?.trialDaysLeft;
      if (sub != null && sub.isOnActiveTrial && daysLeft != null) {
        return l10n.bookStatusTrialDaysLeft(daysLeft);
      }
      return l10n.bookStatusActive;
    }
    return l10n.bookStatusLocked;
  }
}
