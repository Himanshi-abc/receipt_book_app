import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/book_switcher.dart';
import '../../books/providers/book_provider.dart';
import '../../bills/screens/bill_list_screen.dart';
import 'register_section_body.dart';

/// The app's home screen shell: BookSwitcher + business-only nav icons in
/// the AppBar, with the default body depending on the current book:
///
/// - Individual Book: the Income/Expense register (RegisterSectionBody) -
///   there's nothing else to show, so it's both the default and only view.
///   Its AppBar also gets a "download all data as Excel" icon that exports
///   whatever the register currently has on screen (active filters
///   included) - see RegisterSectionBodyState.exportFilteredToExcel.
/// - Business Book: the Bills section (Sales/Purchase) is the default view
///   instead: the register moved behind the "Register" icon above, opened
///   only on tap (see RegisterScreen).
class HomeLedgerScreen extends StatefulWidget {
  const HomeLedgerScreen({super.key});

  @override
  State<HomeLedgerScreen> createState() => _HomeLedgerScreenState();
}

class _HomeLedgerScreenState extends State<HomeLedgerScreen> {
  final _registerKey = GlobalKey<RegisterSectionBodyState>();

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final currentBook = bookProvider.currentBook;
    final isBusiness = currentBook?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(
        title: const BookSwitcher(),
        actions: [
          if (!isBusiness && currentBook != null)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Download all data (Excel)',
              onPressed: () => _registerKey.currentState?.exportFilteredToExcel(),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: () => Navigator.pushNamed(context, '/dashboard'),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Register',
              onPressed: () => Navigator.pushNamed(context, '/register'),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Bills',
              onPressed: () => Navigator.pushNamed(context, '/bills'),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Customers',
              onPressed: () => Navigator.pushNamed(context, '/customers'),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'Suppliers',
              onPressed: () => Navigator.pushNamed(context, '/suppliers'),
            ),
          if (isBusiness)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Products',
              onPressed: () => Navigator.pushNamed(context, '/products'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: currentBook == null
          ? const Center(child: CircularProgressIndicator())
          : isBusiness
              ? const BillsSectionBody()
              : RegisterSectionBody(key: _registerKey),
    );
  }
}
