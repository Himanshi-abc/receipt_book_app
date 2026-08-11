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
import '../../../l10n/app_localizations.dart';
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

/// Individual Book only: date filter for the register list, offered from
/// the filter bottom sheet alongside Categories. "This Year"/"Prev Year"
/// are Indian Financial Years (1 Apr - 31 Mar), not calendar years.
///
/// Carries no label of its own - see [dateFilterLabel]. A hardcoded English
/// label on the enum would be the one string the localization pipeline
/// can't reach, since an enum constant has no BuildContext.
enum DateFilterOption { thisMonth, prevMonth, thisYear, prevYear }

/// The translated label for a [DateFilterOption]. A free function rather
/// than an extension getter so the switch stays exhaustive - adding a
/// fifth option becomes a compile error here instead of silently
/// rendering blank.
String dateFilterLabel(AppLocalizations l10n, DateFilterOption option) =>
    switch (option) {
      DateFilterOption.thisMonth => l10n.dateThisMonth,
      DateFilterOption.prevMonth => l10n.datePrevMonth,
      DateFilterOption.thisYear => l10n.dateThisYear,
      DateFilterOption.prevYear => l10n.datePrevYear,
    };

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
  /// should ever offer for a Business Book (see [_categoryMenuOptionsFor]).
  /// Loaded alongside the transactions, from the same book.
  List<Category> _customCategories = [];

  bool _loading = true;

  /// All/Income/Expense - always visible on screen as its own chip row,
  /// not tucked inside the filter sheet, so switching type stays a single
  /// tap. Selecting a type clears [_categoryFilters], since the category
  /// list itself is scoped to the selected type (see
  /// [_categoryMenuOptionsFor]) and a stale selection could otherwise keep
  /// filtering invisibly.
  TxType? _typeFilter;

  /// Category multi-select: empty means "every category". Only the filter
  /// sheet (see [_openFilterSheet]) writes to this.
  Set<String> _categoryFilters = {};

  DateFilterOption? _dateFilter;

  /// Whether the filter *sheet's* facets (category/date) have anything
  /// active - drives the badge dot on the filter icon. Type isn't counted:
  /// it's always visible on screen, so its own chip already shows whether
  /// it's active.
  bool _hasActiveFilters(bool isBusiness) =>
      _categoryFilters.isNotEmpty || (_dateFilter != null && !isBusiness);

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
      if (_categoryFilters.isNotEmpty && !_categoryFilters.contains(t.categoryId)) return false;
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

  List<Category> _categoryMenuOptionsFor(bool isBusiness, TxType? typeFilter) {
    final all = registerCategoryOptions(
      isBusiness: isBusiness,
      ownCategories: _customCategories,
    );
    return (typeFilter == null ? all : all.where((c) => c.type == typeFilter))
        .toList();
  }

  /// The filter icon button, leftmost next to the search field - tapping it
  /// opens [_openFilterSheet] with the Category (and, Individual Book only,
  /// Date) facets. All/Income/Expense stays out of the sheet entirely - see
  /// the on-screen chip row built in [build] - so a small dot only badges
  /// the icon when the sheet's own facets are active.
  Widget _buildFilterButton(BuildContext context, bool isBusiness) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = _hasActiveFilters(isBusiness);
    return Badge(
      isLabelVisible: active,
      smallSize: 8,
      backgroundColor: theme.colorScheme.primary,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? theme.colorScheme.primary : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: IconButton(
          icon: Icon(
            Icons.filter_list,
            color: active ? theme.colorScheme.primary : null,
          ),
          tooltip: l10n.filters,
          onPressed: () => _openFilterSheet(context, isBusiness),
        ),
      ),
    );
  }

  /// Bottom sheet holding the two remaining facets: Category (checkbox
  /// multi-select - any transaction matching *any* checked category
  /// passes) and, Individual Book only, Date (checkbox-styled but single-
  /// select, since two financial periods can't both apply at once -
  /// checking one clears whichever was checked before). The category list
  /// is scoped to whatever Type is currently active on screen, same as
  /// before. Selections are held locally until "Apply filters" so
  /// cancelling (swipe-down/back) discards changes.
  Future<void> _openFilterSheet(BuildContext context, bool isBusiness) async {
    var tempCategories = Set<String>.of(_categoryFilters);
    DateFilterOption? tempDate = _dateFilter;
    final categoryOptions = _categoryMenuOptionsFor(isBusiness, _typeFilter);

    final result = await showModalBottomSheet<
        ({Set<String> categories, DateFilterOption? date})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(l10n.filters, style: Theme.of(ctx).textTheme.titleLarge),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setSheetState(() {
                              tempCategories = {};
                              tempDate = null;
                            }),
                            child: Text(l10n.actionClearAll),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.category, style: Theme.of(ctx).textTheme.titleSmall),
                      if (categoryOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Text(
                            l10n.noCategoriesYet,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        )
                      else
                        ...categoryOptions.map(
                          (c) => CheckboxListTile(
                            value: tempCategories.contains(c.id),
                            title: Text(systemCategoryName(l10n, c)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (checked) => setSheetState(() {
                              if (checked == true) {
                                tempCategories.add(c.id);
                              } else {
                                tempCategories.remove(c.id);
                              }
                            }),
                          ),
                        ),
                      if (!isBusiness) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(l10n.date, style: Theme.of(ctx).textTheme.titleSmall),
                        ...DateFilterOption.values.map(
                          (o) => CheckboxListTile(
                            value: tempDate == o,
                            title: Text(dateFilterLabel(l10n, o)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (checked) => setSheetState(() {
                              tempDate = checked == true ? o : null;
                            }),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            (categories: tempCategories, date: tempDate),
                          ),
                          child: Text(l10n.actionApplyFilters),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _categoryFilters = result.categories;
      _dateFilter = result.date;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final l10n = AppLocalizations.of(context);
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.md,
                    AppSpacing.pageGutter,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterButton(context, isBusiness),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppSearchField(
                          controller: _searchCtrl,
                          hintText: l10n.searchRegisterHint,
                          onChanged: (_) => setState(_applyFilters),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(l10n.typeAll),
                          selected: _typeFilter == null,
                          onSelected: (_) => setState(() {
                            _typeFilter = null;
                            _categoryFilters = {};
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(l10n.typeIncome),
                          selected: _typeFilter == TxType.income,
                          onSelected: (_) => setState(() {
                            _typeFilter = TxType.income;
                            _categoryFilters = {};
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(l10n.typeExpense),
                          selected: _typeFilter == TxType.expense,
                          onSelected: (_) => setState(() {
                            _typeFilter = TxType.expense;
                            _categoryFilters = {};
                            _applyFilters();
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_categoryFilters.isNotEmpty || (_dateFilter != null && !isBusiness))
                  Padding(
                    padding: const EdgeInsets.only(
                        left: AppSpacing.pageGutter,
                        right: AppSpacing.pageGutter,
                        top: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final categoryId in _categoryFilters)
                            Chip(
                              label: Text(_categoryNameFor(categoryId, isBusiness)),
                              onDeleted: () => setState(() {
                                _categoryFilters = Set.of(_categoryFilters)..remove(categoryId);
                                _applyFilters();
                              }),
                            ),
                          if (_dateFilter != null && !isBusiness)
                            Chip(
                              label: Text(dateFilterLabel(l10n, _dateFilter!)),
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
                                  title: l10n.noTransactionsTitle,
                                  message: writable
                                      ? l10n.noTransactionsMessage
                                      : l10n.noEntriesLockedMessage,
                                  actionLabel: writable ? l10n.addFirstEntry : null,
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
                              : AppEmptyState(
                                  icon: Icons.search_off,
                                  title: l10n.noMatchingEntriesTitle,
                                  message: l10n.noMatchingEntriesMessage,
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
    final l10n = AppLocalizations.of(context);
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportNothingToExport)),
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
            .showSnackBar(SnackBar(content: Text(l10n.exportExcelSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportExcelFailed('$e'))));
      }
    }
  }

  /// Inline banner rather than a blocking dialog: the user can still read
  /// their existing data while locked, they just can't write. The icon +
  /// text pairing means the warning survives greyscale and screen readers.
  Widget _buildLockBanner(BuildContext context, BookProvider bookProvider) {
    final access = bookProvider.accessFor(bookProvider.currentBook!);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  l10n.bookLockedTitle,
                  style: theme.textTheme.titleSmall?.copyWith(color: warning.fg),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  BookAccessService.messageFor(l10n, access.reason),
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
                    child: Text(l10n.switchBookOrUpgrade),
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
