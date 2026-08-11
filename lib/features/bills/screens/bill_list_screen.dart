import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/app_date_range_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../models/bill_date_range.dart';
import 'create_bill_screen.dart';

/// The translated label for a bill date-range preset.
///
/// [BillDateRange.label] stays English-only on purpose: it's a pure model
/// with no BuildContext to resolve a locale from. Custom ranges keep
/// delegating to it, since that branch is a formatted date pair rather
/// than a fixed phrase - and intl already renders those month names in the
/// active locale.
String billRangeLabel(AppLocalizations l10n, BillDateRange range) =>
    switch (range.preset) {
      BillDateRangePreset.thisMonth => l10n.rangeThisMonth,
      BillDateRangePreset.lastMonth => l10n.rangeLastMonth,
      BillDateRangePreset.thisWeek => l10n.rangeThisWeek,
      BillDateRangePreset.lastWeek => l10n.rangeLastWeek,
      BillDateRangePreset.thisYear => l10n.rangeThisYear,
      BillDateRangePreset.lastYear => l10n.rangeLastYear,
      BillDateRangePreset.allTime => l10n.rangeAllTime,
      BillDateRangePreset.custom => range.label,
    };

/// Business Book only, standalone route (kept for any direct/deep-link
/// navigation to '/bills') - [BillsSectionBody] is what actually renders
/// this, embedded directly (no AppBar of its own) as HomeLedgerScreen's
/// default body for a Business Book.
///
/// The optional initial-state params exist for deep links that need to land
/// on a specific view - e.g. the dashboard's Overdue cards, which open this
/// screen already switched to the right direction with Overdue selected.
class BillListScreen extends StatelessWidget {
  final BillDirection initialDirection;
  final BillStatusFilter initialStatusFilter;
  final BillDateRangePreset initialRangePreset;

  const BillListScreen({
    super.key,
    this.initialDirection = BillDirection.sales,
    this.initialStatusFilter = BillStatusFilter.all,
    this.initialRangePreset = BillDateRangePreset.thisMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).billsTitle)),
      body: BillsSectionBody(
        initialDirection: initialDirection,
        initialStatusFilter: initialStatusFilter,
        initialRangePreset: initialRangePreset,
      ),
    );
  }
}

/// All bills within a status bucket - "Pending" combines unpaid + partial,
/// since a partially paid bill still has money left outstanding.
/// "Overdue" is a subset of Pending: still owing *and* past its due date.
///
/// Public because callers deep-link into a preselected filter - see
/// [BillListScreen]'s initial-state params.
enum BillStatusFilter { all, paid, pending, overdue }

/// Sales vs Purchase bills, split by a full-width toggle at the top (Sales
/// selected by default) - with a party name search, a Status filter
/// (Paid/Pending/Overdue, checkbox multi-select) and a Date filter (This
/// Month/Last Month/This Week/Last Week/This Year/Last Year/All Time/
/// Custom) tucked behind a filter icon left of the search bar - same
/// position and sheet style as the Register section's filter - and Total/
/// Pending summary cards scoped to the same range. Returns its own
/// Scaffold (body + FAB only, no AppBar) so it can be embedded directly
/// under someone else's AppBar - see HomeLedgerScreen and [BillListScreen]
/// above.
class BillsSectionBody extends StatefulWidget {
  /// Starting state. All three stay fully editable afterwards - these only
  /// decide what the user lands on. See [BillListScreen].
  final BillDirection initialDirection;
  final BillStatusFilter initialStatusFilter;
  final BillDateRangePreset initialRangePreset;

  const BillsSectionBody({
    super.key,
    this.initialDirection = BillDirection.sales,
    this.initialStatusFilter = BillStatusFilter.all,
    this.initialRangePreset = BillDateRangePreset.thisMonth,
  });

  @override
  State<BillsSectionBody> createState() => _BillsSectionBodyState();
}

class _BillsSectionBodyState extends State<BillsSectionBody> {
  late BillDirection _direction = widget.initialDirection;
  final _searchCtrl = TextEditingController();

  /// Status multi-select: empty means "every status" - same convention as
  /// the Register section's Category filter. [BillStatusFilter.all] is
  /// never itself a set member; it only exists as the external
  /// [initialStatusFilter] API for deep-links (e.g. the dashboard's Overdue
  /// cards land here with `{overdue}` preselected).
  late Set<BillStatusFilter> _statusFilters = widget.initialStatusFilter == BillStatusFilter.all
      ? {}
      : {widget.initialStatusFilter};

  late BillDateRange _range = BillDateRange.forPreset(widget.initialRangePreset);

  bool get _isSales => _direction == BillDirection.sales;

  /// Whether the filter sheet's own facets (status/date) have anything
  /// active - drives the badge dot on the filter icon. Date always has
  /// *some* preset (there's no "off" state for it, unlike Register's
  /// Date), so it only counts as "active" once it's off the default.
  bool get _hasActiveFilters =>
      _statusFilters.isNotEmpty || _range.preset != BillDateRangePreset.thisMonth;

  static String _statusLabel(AppLocalizations l10n, BillStatusFilter f) =>
      switch (f) {
        BillStatusFilter.all => l10n.typeAll,
        BillStatusFilter.paid => l10n.paid,
        BillStatusFilter.pending => l10n.pending,
        BillStatusFilter.overdue => l10n.overdue,
      };

  /// The filter icon button, leftmost next to the search field - same spot
  /// and look as the Register section's. Opens [_openFilterSheet] with
  /// Status (Paid/Pending/Overdue) and Date; Sales/Purchase stays out of
  /// the sheet entirely since it's the always-visible toggle above.
  Widget _buildFilterButton(BuildContext context, {required int overdueCount}) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = _hasActiveFilters;
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
          onPressed: () => _openFilterSheet(context, overdueCount: overdueCount),
        ),
      ),
    );
  }

  /// Bottom sheet holding Status (checkbox multi-select - a bill matching
  /// *any* checked status passes) and Date (checkbox-styled but
  /// single-select, since only one period can apply at once - checking one
  /// clears whichever was checked before; Custom immediately opens the
  /// range picker, same as the old dropdown did). Selections are held
  /// locally until "Apply filters" so cancelling discards changes.
  Future<void> _openFilterSheet(BuildContext context, {required int overdueCount}) async {
    var tempStatuses = Set<BillStatusFilter>.of(_statusFilters);
    var tempRange = _range;

    final result = await showModalBottomSheet<
        ({Set<BillStatusFilter> statuses, BillDateRange range})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickCustom() async {
              final now = DateTime.now();
              // Bills can be dated up to five years back and, via the bill
              // form's own date picker, into the future - so the filter has
              // to reach both ways or it can't select ranges that contain
              // real bills.
              final picked = await AppDateRangeDialog.show(
                ctx,
                initialStart: tempRange.start,
                initialEnd: tempRange.end,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5, 12, 31),
                title: l10n.customDateRangeTitle,
              );
              if (picked != null) {
                setSheetState(() {
                  tempRange = BillDateRange.forPreset(
                    BillDateRangePreset.custom,
                    customStart: picked.start,
                    // End-of-day: a bill dated on the last day of the range
                    // must fall inside it, and BillDateRange.contains
                    // compares raw DateTimes.
                    customEnd: DateTime(
                        picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                  );
                });
              }
            }

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
                              tempStatuses = {};
                              tempRange = BillDateRange.forPreset(BillDateRangePreset.thisMonth);
                            }),
                            child: Text(l10n.actionClearAll),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.status, style: Theme.of(ctx).textTheme.titleSmall),
                      for (final f in [
                        BillStatusFilter.paid,
                        BillStatusFilter.pending,
                        BillStatusFilter.overdue,
                      ])
                        CheckboxListTile(
                          value: tempStatuses.contains(f),
                          title: Text(_statusLabel(l10n, f)),
                          subtitle: f == BillStatusFilter.overdue && overdueCount > 0
                              ? Text(l10n.billsCount(overdueCount))
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (checked) => setSheetState(() {
                            if (checked == true) {
                              tempStatuses.add(f);
                            } else {
                              tempStatuses.remove(f);
                            }
                          }),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.date, style: Theme.of(ctx).textTheme.titleSmall),
                      for (final p in BillDateRangePreset.values)
                        CheckboxListTile(
                          value: tempRange.preset == p,
                          title: Text(
                            p == BillDateRangePreset.custom
                                ? (tempRange.preset == BillDateRangePreset.custom
                                    ? tempRange.label
                                    : l10n.customRange)
                                : billRangeLabel(l10n, BillDateRange.forPreset(p)),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (checked) {
                            if (checked != true) {
                              setSheetState(() => tempRange =
                                  BillDateRange.forPreset(BillDateRangePreset.thisMonth));
                              return;
                            }
                            if (p == BillDateRangePreset.custom) {
                              pickCustom();
                            } else {
                              setSheetState(() => tempRange = BillDateRange.forPreset(p));
                            }
                          },
                        ),
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            (statuses: tempStatuses, range: tempRange),
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
      _statusFilters = result.statuses;
      _range = result.range;
    });
  }

  Widget _buildSummaryCard(String label, int paise, AppTone tone, IconData icon) {
    return Expanded(
      child: AppStatCard(
        label: label,
        amountPaise: paise,
        tone: tone,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final l10n = AppLocalizations.of(context);
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);

    return Scaffold(
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SegmentedButton<BillDirection>(
                    segments: [
                      ButtonSegment(
                          value: BillDirection.sales, label: Text(l10n.sales)),
                      ButtonSegment(
                          value: BillDirection.purchase, label: Text(l10n.purchase)),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (s) => setState(() => _direction = s.first),
                    // Full width, not sized to its own content - Sales and
                    // Purchase should each take half the screen, not sit
                    // squeezed in the middle sharing the row with anything
                    // else (the Date filter moved into the filter sheet).
                    expandedInsets: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Invoice>>(
                    stream: InvoiceRepository().watchInvoices(book.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final inRange = snapshot.data!
                          .where((i) =>
                              i.docType == InvoiceDocType.invoice &&
                              i.billDirection == _direction &&
                              _range.contains(i.invoiceDate))
                          .toList();

                      final totalAmountPaise =
                          inRange.fold<int>(0, (a, i) => a + i.grandTotalPaise);
                      final pendingBills =
                          inRange.where((i) => i.status != InvoiceStatus.paid).toList();
                      final pendingAmountPaise =
                          pendingBills.fold<int>(0, (a, i) => a + i.balanceDuePaise);

                      // Same Invoice.isOverdue the dashboard's overdue cards
                      // use, so this list and those totals agree.
                      final now = DateTime.now();
                      final overdueBills =
                          pendingBills.where((i) => i.isOverdue(now)).toList();

                      // A bill matching *any* checked status passes - empty
                      // set means every status. Order follows inRange
                      // (chronological) except when Overdue is the only
                      // thing checked, matching the old single-select
                      // behaviour: soonest-overdue last, since that's the
                      // one you're chasing hardest.
                      final statusFiltered = _statusFilters.isEmpty
                          ? inRange
                          : inRange
                              .where((i) =>
                                  (_statusFilters.contains(BillStatusFilter.paid) &&
                                      i.status == InvoiceStatus.paid) ||
                                  (_statusFilters.contains(BillStatusFilter.pending) &&
                                      i.status != InvoiceStatus.paid) ||
                                  (_statusFilters.contains(BillStatusFilter.overdue) &&
                                      i.status != InvoiceStatus.paid &&
                                      i.isOverdue(now)))
                              .toList();
                      final overdueOnly = _statusFilters.length == 1 &&
                          _statusFilters.single == BillStatusFilter.overdue;
                      if (overdueOnly) {
                        statusFiltered
                            .sort((a, b) => a.effectiveDueDate.compareTo(b.effectiveDueDate));
                      }

                      final query = _searchCtrl.text.trim().toLowerCase();
                      final bills = query.isEmpty
                          ? statusFiltered
                          : statusFiltered
                              .where((i) => i.customerName.toLowerCase().contains(query))
                              .toList();

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                _buildSummaryCard(
                                  _isSales ? l10n.totalSales : l10n.totalPurchase,
                                  totalAmountPaise,
                                  AppTone.info,
                                  _isSales
                                      ? Icons.receipt_long_outlined
                                      : Icons.inventory_2_outlined,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _buildSummaryCard(
                                  _isSales ? l10n.pendingToCollect : l10n.pendingToPay,
                                  pendingAmountPaise,
                                  _isSales ? AppTone.positive : AppTone.negative,
                                  _isSales ? Icons.call_received : Icons.call_made,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pageGutter),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFilterButton(context, overdueCount: overdueBills.length),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppSearchField(
                                    controller: _searchCtrl,
                                    hintText: _isSales
                                        ? l10n.searchCustomerHint
                                        : l10n.searchSupplierHint,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_statusFilters.isNotEmpty ||
                              _range.preset != BillDateRangePreset.thisMonth)
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
                                    for (final f in _statusFilters)
                                      Chip(
                                        label: Text(_statusLabel(l10n, f)),
                                        onDeleted: () => setState(() {
                                          _statusFilters = Set.of(_statusFilters)..remove(f);
                                        }),
                                      ),
                                    if (_range.preset != BillDateRangePreset.thisMonth)
                                      Chip(
                                        label: Text(billRangeLabel(l10n, _range)),
                                        onDeleted: () => setState(() => _range =
                                            BillDateRange.forPreset(
                                                BillDateRangePreset.thisMonth)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: bills.isEmpty
                                // An empty Overdue list is good news, not a
                                // failed search - saying "try widening the
                                // filters" would read as if something's wrong.
                                ? overdueOnly && _searchCtrl.text.trim().isEmpty
                                    ? AppEmptyState(
                                        icon: Icons.check_circle_outline,
                                        title: l10n.nothingOverdueTitle,
                                        message: _isSales
                                            ? l10n.nothingOverdueSalesMessage
                                            : l10n.nothingOverduePurchaseMessage,
                                        tone: AppTone.positive,
                                      )
                                    : AppEmptyState(
                                        icon: Icons.receipt_long_outlined,
                                        title: _isSales
                                            ? l10n.noSalesBillsFound
                                            : l10n.noPurchaseBillsFound,
                                        message: l10n.noBillsMatchMessage,
                                      )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.pageGutter,
                                      AppSpacing.xs,
                                      AppSpacing.pageGutter,
                                      AppSpacing.giant + AppSpacing.xxl,
                                    ),
                                    itemCount: bills.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (ctx, i) {
                                      final bill = bills[i];
                                      return BillRow(
                                        bill: bill,
                                        onTap: () =>
                                            _showBillActions(context, book, bill),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: access.writable
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_isSales ? l10n.newSale : l10n.newPurchase),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateBillScreen(book: book, direction: _direction),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _showBillActions(BuildContext context, Book book, Invoice bill) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(l10n.viewInvoice),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editInvoice),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.shareInvoice),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(l10n.printInvoice),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(l10n.deleteInvoice,
                    style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoicePreviewShareScreen(invoice: bill, book: book)),
        );
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateBillScreen(
              book: book,
              direction: bill.billDirection,
              existingInvoice: bill,
            ),
          ),
        );
        break;
      case 'share':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePreviewShareScreen(
              invoice: bill,
              book: book,
              autoAction: PreviewAutoAction.share,
            ),
          ),
        );
        break;
      case 'print':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePreviewShareScreen(
              invoice: bill,
              book: book,
              autoAction: PreviewAutoAction.print,
            ),
          ),
        );
        break;
      case 'delete':
        _confirmAndDelete(context, bill);
        break;
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, Invoice bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.deleteInvoice),
          content: Text(l10n.deleteInvoiceConfirm(bill.invoiceNumber)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.actionDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await InvoiceRepository().deleteInvoice(bill.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).invoiceDeleted(bill.invoiceNumber),
          ),
        ),
      );
    }
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

/// One bill row.
///
/// The status was previously buried in a run-on subtitle
/// ("27/7/2026 · Partially Paid"). It's now a coloured badge, because
/// "which of these is still unpaid?" is the single most common question
/// asked of this list - it should be answerable by scanning, not reading.
class BillRow extends StatelessWidget {
  final Invoice bill;
  final VoidCallback onTap;

  const BillRow({super.key, required this.bill, required this.onTap});

  static ({String label, AppTone tone}) _status(
          AppLocalizations l10n, InvoiceStatus s) =>
      switch (s) {
        InvoiceStatus.paid => (label: l10n.paid, tone: AppTone.positive),
        InvoiceStatus.partial =>
          (label: l10n.statusPartPaid, tone: AppTone.warning),
        InvoiceStatus.unpaid =>
          (label: l10n.statusUnpaid, tone: AppTone.negative),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final l10n = AppLocalizations.of(context);
    final status = _status(l10n, bill.status);
    final statusTone = tones.byTone(status.tone);
    final date = bill.invoiceDate;

    // Only meaningful while money is still owed - a paid bill's due date is
    // history, and repeating it would just dilute the row.
    final showDue = bill.status != InvoiceStatus.paid;
    final due = bill.effectiveDueDate;
    final daysLeft = bill.daysUntilDue(DateTime.now());
    // Only colored once it's actually worth acting on - a due date three
    // weeks out is reference information, not an alert.
    final dueColor = daysLeft < 0
        ? tones.byTone(AppTone.negative).fg
        : daysLeft <= 3
            ? tones.byTone(AppTone.warning).fg
            : tones.textTertiary;

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bill.customerName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${bill.invoiceNumber}  ·  '
                      '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tones.textTertiary)
                          .tabular,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showDue) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.dueOn('${due.day.toString().padLeft(2, '0')}/'
                                '${due.month.toString().padLeft(2, '0')}/${due.year}') +
                            (daysLeft < 0 ? '  ·  ${l10n.overdue}' : ''),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: dueColor)
                            .tabular,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    bill.grandTotalPaise,
                    muted: true,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusTone.bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: statusTone.border),
                    ),
                    child: Text(
                      status.label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: statusTone.fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
