import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/services/category_repository.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../books/providers/book_provider.dart';
import '../services/register_excel_service.dart';
import '../widgets/transaction_tile.dart';
import '../../scan/screens/scan_choice_screen.dart';
import '../../transaction_detail/screens/transaction_detail_screen.dart';

/// The categories the Register's "Categories" filter can offer for a book.
///
/// Business Book: only [ownCategories] - the book's own saved categories,
/// and nothing else. Matches OcrReviewFormScreen's entry form (see its
/// _categoryOptions), which already treats a Business Book as having no
/// built-in categories at all - only what the user created for *this*
/// book. Individual Book: the fixed [Category.defaultsFor] list, with the
/// book's own categories layered on top - same combination the entry form
/// uses there too.
///
/// A free function, not a method on [RegisterSectionBodyState], so the
/// logic that was actually wrong - the filter offering categories that
/// don't exist in this book - can be tested without a Firestore-backed
/// widget around it.
List<Category> registerCategoryOptions({
  required bool isBusiness,
  required List<Category> ownCategories,
}) =>
    [
      if (!isBusiness) ...Category.defaultsFor(isBusiness),
      ...ownCategories,
    ];

/// Individual Book only: date filter for the register list, matching the
/// same "tab dropdown" UI as the Categories filter. "This Year"/"Prev Year"
/// are Indian Financial Years (1 Apr - 31 Mar), not calendar years.
enum DateFilterOption {
  thisMonth('This Month'),
  prevMonth('Prev Month'),
  thisYear('This Year'),
  prevYear('Prev Year');

  final String label;
  const DateFilterOption(this.label);
}

/// The Income/Expense register: search, type/category filters, and the
/// transaction list. Returns its own Scaffold (body + FAB only, no AppBar)
/// so it can be embedded directly under someone else's AppBar.
///
/// - Individual Book: this is HomeLedgerScreen's only body - the register
///   *is* the home screen.
/// - Business Book: HomeLedgerScreen's default body is the Bills section
///   instead; this is reached via the "Register" icon (see RegisterScreen).
class RegisterSectionBody extends StatefulWidget {
  const RegisterSectionBody({super.key});

  @override
  State<RegisterSectionBody> createState() => RegisterSectionBodyState();
}

class RegisterSectionBodyState extends State<RegisterSectionBody> {
  final _repo = TransactionRepository();
  final _categoryRepo = CategoryRepository();
  final _searchCtrl = TextEditingController();
  List<AppTransaction> _all = [];
  List<AppTransaction> _filtered = [];

  /// This book's own categories - the only ones the Categories filter
  /// should ever offer for a Business Book (see [_categoryMenuOptions]).
  /// Loaded alongside the transactions, from the same book.
  List<Category> _customCategories = [];

  bool _loading = true;
  TxType? _typeFilter;
  String? _categoryFilter;
  bool _categoryMenuOpen = false;
  DateFilterOption? _dateFilter;
  bool _dateMenuOpen = false;

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
    final categories = await _categoryRepo.loadCategories(bookId);
    setState(() {
      _all = txs;
      _customCategories = categories;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final range = _dateRangeFor(_dateFilter);
    _filtered = _all.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) return false;
      if (range != null && (t.date.isBefore(range.start) || t.date.isAfter(range.end))) {
        return false;
      }
      if (query.isEmpty) return true;
      return t.vendorOrCustomerName.toLowerCase().contains(query) ||
          (t.notes ?? '').toLowerCase().contains(query);
    }).toList();
  }

  /// [DateFilterOption.thisYear]/[DateFilterOption.prevYear] are Indian
  /// Financial Years (1 Apr - 31 Mar), not calendar years.
  DateTimeRange? _dateRangeFor(DateFilterOption? option) {
    final now = DateTime.now();
    switch (option) {
      case null:
        return null;
      case DateFilterOption.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
        return DateTimeRange(start: start, end: end);
      case DateFilterOption.prevMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 1).subtract(const Duration(microseconds: 1));
        return DateTimeRange(start: start, end: end);
      case DateFilterOption.thisYear:
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        final start = DateTime(fyStartYear, 4, 1);
        final end = DateTime(fyStartYear + 1, 4, 1).subtract(const Duration(microseconds: 1));
        return DateTimeRange(start: start, end: end);
      case DateFilterOption.prevYear:
        final fyStartYear = (now.month >= 4 ? now.year : now.year - 1) - 1;
        final start = DateTime(fyStartYear, 4, 1);
        final end = DateTime(fyStartYear + 1, 4, 1).subtract(const Duration(microseconds: 1));
        return DateTimeRange(start: start, end: end);
    }
  }

  String _categoryNameFor(String categoryId, bool isBusiness) {
    final matches = registerCategoryOptions(
      isBusiness: isBusiness,
      ownCategories: _customCategories,
    ).where((c) => c.id == categoryId);
    return matches.isEmpty ? categoryId : matches.first.name;
  }

  List<Category> _categoryMenuOptions(bool isBusiness) {
    final all = registerCategoryOptions(
      isBusiness: isBusiness,
      ownCategories: _customCategories,
    );
    return (_typeFilter == null ? all : all.where((c) => c.type == _typeFilter))
        .toList();
  }

  /// A "Categories" tab-style dropdown, leftmost in the filter row (before
  /// "All") - matches the underlined tab look used elsewhere in the design
  /// (active tab in accent color with an underline). Same for both
  /// Individual and Business Books; [isBusiness] only picks which category
  /// list (see [registerCategoryOptions]) the dropdown offers.
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

  /// Individual Book only: a "Date" tab-style dropdown matching
  /// [_buildCategoriesFilterTab]'s look (see that method for the design
  /// rationale). Offers This Month / Prev Month / This Year / Prev Year,
  /// where the year options are Financial Years (1 Apr - 31 Mar).
  Widget _buildDateFilterTab(BuildContext context) {
    final active = _dateFilter != null || _dateMenuOpen;
    final accentColor = Theme.of(context).colorScheme.primary;
    final color = active ? accentColor : Theme.of(context).textTheme.bodyLarge?.color;

    return PopupMenuButton<DateFilterOption?>(
      tooltip: 'Filter by date',
      onOpened: () => setState(() => _dateMenuOpen = true),
      onCanceled: () => setState(() => _dateMenuOpen = false),
      onSelected: (value) => setState(() {
        _dateMenuOpen = false;
        _dateFilter = value;
        _applyFilters();
      }),
      itemBuilder: (ctx) => [
        const PopupMenuItem<DateFilterOption?>(value: null, child: Text('All dates')),
        const PopupMenuDivider(),
        ...DateFilterOption.values
            .map((o) => PopupMenuItem<DateFilterOption?>(value: o, child: Text(o.label))),
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
            Text('Date', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Icon(
              _dateMenuOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
      body: currentBook == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!writable) _buildLockBanner(context, bookProvider),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageGutter, vertical: AppSpacing.md),
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Search vendor, notes, category...',
                    onChanged: (_) => setState(_applyFilters),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoriesFilterTab(context, isBusiness),
                        if (!isBusiness) ...[
                          const SizedBox(width: 16),
                          _buildDateFilterTab(context),
                        ],
                        const SizedBox(width: 16),
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
                      ],
                    ),
                  ),
                ),
                if (_categoryFilter != null || (_dateFilter != null && !isBusiness))
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_categoryFilter != null)
                            Chip(
                              label: Text(_categoryNameFor(_categoryFilter!, isBusiness)),
                              onDeleted: () => setState(() {
                                _categoryFilter = null;
                                _applyFilters();
                              }),
                            ),
                          if (_dateFilter != null && !isBusiness)
                            Chip(
                              label: Text(_dateFilter!.label),
                              onDeleted: () => setState(() {
                                _dateFilter = null;
                                _applyFilters();
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? (_all.isEmpty
                              ? AppEmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No transactions yet',
                                  message: writable
                                      ? 'Scan a receipt or add an entry manually to start '
                                          'building your books.'
                                      : 'This book has no entries yet.',
                                  actionLabel: writable ? 'Add first entry' : null,
                                  onAction: writable
                                      ? () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const ScanChoiceScreen()),
                                          );
                                          _load();
                                        }
                                      : null,
                                )
                              : const AppEmptyState(
                                  icon: Icons.search_off,
                                  title: 'No matching entries',
                                  message:
                                      'Nothing matches the current search and filters. '
                                      'Try clearing one of them.',
                                ))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageGutter,
                                  AppSpacing.xs,
                                  AppSpacing.pageGutter,
                                  // Clears the FAB.
                                  AppSpacing.giant + AppSpacing.xxl,
                                ),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
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

  /// Individual Book only: called from HomeLedgerScreen's AppBar download
  /// icon (via a GlobalKey) to export exactly what's on screen right now -
  /// i.e. with the active search/type/category/date filters applied.
  /// Excludes attachments; text fields only (see RegisterExcelService).
  Future<void> exportFilteredToExcel() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export for the current filters.')),
      );
      return;
    }
    final bytes = RegisterExcelService.generate(_filtered);
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: 'individual_book_transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        bytes: bytes,
      );
      // null means the user cancelled the save dialog - not an error.
      if (path != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Excel file saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save Excel file: $e')));
      }
    }
  }

  /// Inline banner rather than a blocking dialog: the user can still read
  /// their existing data while locked, they just can't write. The icon +
  /// text pairing means the warning survives greyscale and screen readers.
  Widget _buildLockBanner(BuildContext context, BookProvider bookProvider) {
    final access = bookProvider.accessFor(bookProvider.currentBook!);
    final theme = Theme.of(context);
    final warning = context.tones.warning;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warning.bg,
        border: Border(bottom: BorderSide(color: warning.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.md,
        AppSpacing.pageGutter,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: warning.fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This book is locked',
                  style: theme.textTheme.titleSmall?.copyWith(color: warning.fg),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  BookAccessService.messageFor(access.reason),
                  style: theme.textTheme.bodySmall?.copyWith(color: warning.fg),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: warning.fg,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/settings/manage-books'),
                    child: const Text('Switch active book / Upgrade'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
