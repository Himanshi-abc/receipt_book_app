import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            current?.name ?? 'Select a book',
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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Switch Book', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...bookProvider.books.map((book) {
                final access = bookProvider.accessFor(book);
                return ListTile(
                  leading: Icon(book.isIndividual ? Icons.person : Icons.storefront),
                  title: Text(book.name),
                  subtitle: Text(_statusLabel(book, access, bookProvider)),
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
                title: const Text('Add Business Book'),
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

  String _statusLabel(Book book, BookAccessResult access, BookProvider bookProvider) {
    if (book.isIndividual) return 'Always free';
    if (access.writable) {
      final sub = bookProvider.subscription;
      if (sub != null && sub.isOnActiveTrial) {
        return 'Trial · ${sub.trialDaysLeft} days left';
      }
      return 'Active';
    }
    return 'Locked — Upgrade to unlock';
  }
}
