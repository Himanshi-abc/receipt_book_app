import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/book_switcher.dart';
import '../../books/providers/book_provider.dart';
import '../widgets/transaction_tile.dart';
import '../../scan/screens/scan_choice_screen.dart';
import '../../transaction_detail/screens/transaction_detail_screen.dart';

class HomeLedgerScreen extends StatefulWidget {
  const HomeLedgerScreen({super.key});

  @override
  State<HomeLedgerScreen> createState() => _HomeLedgerScreenState();
}

class _HomeLedgerScreenState extends State<HomeLedgerScreen> {
  final _repo = TransactionRepository();
  final _searchCtrl = TextEditingController();
  List<AppTransaction> _all = [];
  List<AppTransaction> _filtered = [];
  bool _loading = true;
  TxType? _typeFilter;
  String? _categoryFilter;
  bool _categoryMenuOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final bookId = context.read<BookProvider>().currentBook?.id;
    if (bookId == null) return;
    setState(() => _loading = true);
    final txs = await _repo.loadTransactions(bookId);
    setState(() {
      _all = txs;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    _filtered = _all.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) return false;
      if (query.isEmpty) return true;
      return t.vendorOrCustomerName.toLowerCase().contains(query) ||
          (t.notes ?? '').toLowerCase().contains(query);
    }).toList();
  }

  String _categoryNameFor(String categoryId, bool isBusiness) {
    final matches =
        Category.defaultsFor(isBusiness).where((c) => c.id == categoryId);
    return matches.isEmpty ? categoryId : matches.first.name;
  }

  List<Category> _categoryMenuOptions(bool isBusiness) => (_typeFilter == null
          ? Category.defaultsFor(isBusiness)
          : Category.defaultsFor(isBusiness).where((c) => c.type == _typeFilter))
      .toList();

  /// Individual Book only: a "Categories" tab-style dropdown, leftmost in
  /// the filter row (before "All") - matches the underlined tab look used
  /// elsewhere in the design (active tab in accent color with an underline).
  Widget _buildCategoriesFilterTab(BuildContext context, bool isBusiness) {
    final active = _categoryFilter != null || _categoryMenuOpen;
    final accentColor = Theme.of(context).colorScheme.primary;
    final color = active ? accentColor : Theme.of(context).textTheme.bodyLarge?.color;

    return PopupMenuButton<String?>(
      tooltip: 'Filter by category',
      onOpened: () => setState(() => _categoryMenuOpen = true),
      onCanceled: () => setState(() => _categoryMenuOpen = false),
      onSelected: (value) => setState(() {
        _categoryMenuOpen = false;
        _categoryFilter = value;
        _applyFilters();
      }),
      itemBuilder: (ctx) => [
        const PopupMenuItem<String?>(value: null, child: Text('All categories')),
        const PopupMenuDivider(),
        ..._categoryMenuOptions(isBusiness)
            .map((c) => PopupMenuItem<String?>(value: c.id, child: Text(c.name))),
      ],
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? accentColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Categories',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Icon(
              _categoryMenuOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final currentBook = bookProvider.currentBook;
    final writable = bookProvider.currentBookIsWritable;
    final isBusiness = currentBook?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(
        title: const BookSwitcher(),
        actions: [
          if (currentBook?.isBusiness == true)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Dashboard',
              onPressed: () => Navigator.pushNamed(context, '/dashboard'),
            ),
          if (currentBook?.isBusiness == true)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Bills',
              onPressed: () => Navigator.pushNamed(context, '/bills'),
            ),
          if (currentBook?.isBusiness == true)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Customers',
              onPressed: () => Navigator.pushNamed(context, '/customers'),
            ),
          if (currentBook?.isBusiness == true)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'Suppliers',
              onPressed: () => Navigator.pushNamed(context, '/suppliers'),
            ),
          if (currentBook?.isBusiness == true)
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
          : Column(
              children: [
                if (!writable) _buildLockBanner(context, bookProvider),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search vendor, notes, category...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(_applyFilters),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (!isBusiness) ...[
                          _buildCategoriesFilterTab(context, isBusiness),
                          const SizedBox(width: 16),
                        ],
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _typeFilter == null,
                          onSelected: (_) => setState(() {
                            _typeFilter = null;
                            _categoryFilter = null;
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: _typeFilter == TxType.income,
                          onSelected: (_) => setState(() {
                            _typeFilter = TxType.income;
                            _categoryFilter = null;
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Expense'),
                          selected: _typeFilter == TxType.expense,
                          onSelected: (_) => setState(() {
                            _typeFilter = TxType.expense;
                            _categoryFilter = null;
                            _applyFilters();
                          }),
                        ),
                        if (isBusiness) ...[
                          const SizedBox(width: 16),
                          PopupMenuButton<String?>(
                            icon: Icon(
                              Icons.filter_alt,
                              color: _categoryFilter != null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            tooltip: 'Filter by category',
                            onSelected: (value) => setState(() {
                              _categoryFilter = value;
                              _applyFilters();
                            }),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem<String?>(
                                value: null,
                                child: Text('All categories'),
                              ),
                              const PopupMenuDivider(),
                              ..._categoryMenuOptions(isBusiness).map((c) =>
                                  PopupMenuItem<String?>(value: c.id, child: Text(c.name))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_categoryFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(_categoryNameFor(_categoryFilter!, isBusiness)),
                        onDeleted: () => setState(() {
                          _categoryFilter = null;
                          _applyFilters();
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? const Center(child: Text('No transactions yet.'))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final tx = _filtered[i];
                                  return TransactionTile(
                                    transaction: tx,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TransactionDetailScreen(transactionId: tx.id, bookId: tx.bookId),
                                        ),
                                      );
                                      _load();
                                    },
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: writable
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanChoiceScreen()),
                );
                _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLockBanner(BuildContext context, BookProvider bookProvider) {
    final access = bookProvider.accessFor(bookProvider.currentBook!);
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This book is locked',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
          ),
          const SizedBox(height: 4),
          Text(BookAccessService.messageFor(access.reason)),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/settings/manage-books'),
                child: const Text('Switch active book / Upgrade'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
