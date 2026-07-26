import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/utils/money.dart';
import '../../books/providers/book_provider.dart';
import '../services/product_repository.dart';
import '../services/stock_excel_service.dart';
import 'add_product_screen.dart';

/// Business Book only; the caller is responsible for gating navigation to
/// this screen behind `currentBook?.isBusiness == true` (see HomeLedgerScreen).
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _repo = ProductRepository();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Product> _all = [];
  List<Product> _filtered = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final bookId = context.read<BookProvider>().currentBook?.id;
    if (bookId == null) return;
    setState(() => _loading = true);
    final products = await _repo.loadProducts(bookId);
    setState(() {
      _all = products;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    _filtered = query.isEmpty
        ? List<Product>.from(_all)
        : _all.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _downloadStockExcel() async {
    if (_all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a product first.')),
      );
      return;
    }
    final bytes = StockExcelService.generate(_all);
    final file = XFile.fromData(
      bytes,
      name: 'products.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await Share.shareXFiles([file]);
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Download stock excel',
            onPressed: _downloadStockExcel,
          ),
        ],
      ),
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search products by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(_applyFilter),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _all.isEmpty
                                    ? 'No products yet. Tap + to add one.'
                                    : 'No matches found.',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final p = _filtered[i];
                                  return ListTile(
                                    title: Text(p.name),
                                    subtitle: Text(
                                      p.type == ProductItemType.product ? 'Product' : 'Service',
                                    ),
                                    trailing: Text(
                                      Money.format(p.sellingPricePaise),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddProductScreen(existingProduct: p),
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
      floatingActionButton: access.writable
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
                _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLockedState(BookAccessResult access) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(BookAccessService.messageFor(access.reason), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/settings/manage-books'),
              child: const Text('Switch Active Book / Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
