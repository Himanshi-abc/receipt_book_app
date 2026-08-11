import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/money_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/providers/book_provider.dart';
import '../services/product_pdf_service.dart';
import '../services/product_repository.dart';
import 'add_product_screen.dart';

/// Business Book only; the caller is responsible for gating navigation to
/// this screen behind `currentBook?.isBusiness == true` (see HomeLedgerScreen).
class ProductListScreen extends StatefulWidget {
  /// When true this renders without its own AppBar, because HomeLedgerScreen's
  /// shell already provides one. The PDF action moves up there too, driven
  /// through [ProductListScreenState.downloadProductsPdf].
  final bool embedded;

  const ProductListScreen({super.key, this.embedded = false});

  @override
  State<ProductListScreen> createState() => ProductListScreenState();
}

class ProductListScreenState extends State<ProductListScreen> {
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
        : _all
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                (p.productCode?.toString().contains(query) ?? false))
            .toList();
  }

  Future<void> downloadProductsPdf() async {
    final l10n = AppLocalizations.of(context);
    if (_all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addAProductFirst)),
      );
      return;
    }
    final book = context.read<BookProvider>().currentBook;
    if (book == null) return;
    try {
      final bytes = await ProductPdfService.generate(book: book, products: _all);
      final path = await FilePicker.platform.saveFile(
        fileName: 'products_${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: bytes,
      );
      // null means the user cancelled the save dialog - not an error.
      if (path != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.pdfSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.couldNotSavePdf('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(l10n.navProducts),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: l10n.downloadProductListPdf,
                  onPressed: downloadProductsPdf,
                ),
              ],
            ),
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageGutter, vertical: AppSpacing.md),
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: l10n.searchProductsHint,
                    onChanged: (_) => setState(_applyFilter),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? (_all.isEmpty
                              ? AppEmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: l10n.noProductsYet,
                                  message: l10n.noProductsYetMessage,
                                  actionLabel: l10n.addProduct,
                                  onAction: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const AddProductScreen()),
                                    );
                                    _load();
                                  },
                                )
                              : AppEmptyState(
                                  icon: Icons.search_off,
                                  title: l10n.noMatches,
                                  message: l10n.noProductMatchesSearch,
                                ))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageGutter,
                                  AppSpacing.xs,
                                  AppSpacing.pageGutter,
                                  AppSpacing.giant + AppSpacing.xxl,
                                ),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.xs),
                                itemBuilder: (ctx, i) {
                                  final p = _filtered[i];
                                  return _ProductRow(
                                    product: p,
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
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.lock_outline,
      title: l10n.bookLockedTitle,
      message: BookAccessService.messageFor(l10n, access.reason),
      tone: AppTone.warning,
      actionLabel: l10n.switchBookOrUpgrade,
      onAction: () => Navigator.pushNamed(context, '/settings/manage-books'),
    );
  }
}

/// One product/service row: code badge, name, price - nothing else.
///
/// Deliberately a single line. The "Product"/"Service" label used to sit
/// under the name, which forced a two-line row for a distinction that is
/// the same on nearly every entry and that the edit screen states plainly
/// anyway. Dropping it lets the row collapse to one line, so more of the
/// catalogue fits on screen at once - which is what this list is for.
///
/// The product code sits in a monospaced-feel badge rather than a
/// `CircleAvatar`: codes run to 2-3 digits and were being clipped inside a
/// 32px circle, and a squircle badge reads as an identifier rather than as
/// a person.
class _ProductRow extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                height: 30,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tones.neutral.bg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: tones.neutral.border),
                ),
                child: Text(
                  product.productCode?.toString() ?? '—',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: tones.textSecondary)
                      .tabular,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  product.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MoneyText(
                product.sellingPricePaise,
                muted: true,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
