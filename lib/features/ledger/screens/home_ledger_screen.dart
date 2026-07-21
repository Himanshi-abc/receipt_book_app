import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/transaction_model.dart';
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
      if (query.isEmpty) return true;
      return t.vendorOrCustomerName.toLowerCase().contains(query) ||
          (t.notes ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final currentBook = bookProvider.currentBook;
    final writable = bookProvider.currentBookIsWritable;

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
              tooltip: 'Invoices',
              onPressed: () => Navigator.pushNamed(context, '/invoices'),
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
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _typeFilter == null,
                        onSelected: (_) => setState(() {
                          _typeFilter = null;
                          _applyFilters();
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _typeFilter == TxType.income,
                        onSelected: (_) => setState(() {
                          _typeFilter = TxType.income;
                          _applyFilters();
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Expense'),
                        selected: _typeFilter == TxType.expense,
                        onSelected: (_) => setState(() {
                          _typeFilter = TxType.expense;
                          _applyFilters();
                        }),
                      ),
                    ],
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
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Scan'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanChoiceScreen()),
                );
                _load();
              },
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
