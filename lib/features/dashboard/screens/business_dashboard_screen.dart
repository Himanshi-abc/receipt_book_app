import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/navigation/business_section.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/app_date_range_dialog.dart';
import '../../bills/models/bill_date_range.dart';
import '../../bills/screens/bill_list_screen.dart';
import '../../bills/screens/due_bills_screen.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../models/dashboard_date_range.dart';
import '../models/dashboard_data.dart';
import '../services/dashboard_service.dart';
import '../widgets/summary_numbers_row.dart';
import '../widgets/trend_chart.dart';
import '../widgets/expense_category_breakdown.dart';
import '../widgets/top_contacts_list.dart';
import '../widgets/top_products_list.dart';
import '../widgets/outstanding_summary_cards.dart';
import '../widgets/due_bills_cards.dart';

/// SRS 4.4 (only visible inside a Business Book) + Section 8's rule that
/// "dashboard load" is one of the three actions gated by the shared
/// writable-book check. A locked book shows the upgrade prompt instead of
/// ever computing/rendering the numbers.
class BusinessDashboardScreen extends StatefulWidget {
  /// When true this renders without its own AppBar, because
  /// HomeLedgerScreen's shell already provides one.
  final bool embedded;

  const BusinessDashboardScreen({super.key, this.embedded = false});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _repo = TransactionRepository();
  final _invoiceRepo = InvoiceRepository();
  DashboardDateRange _range = DashboardDateRange.forPreset(DateRangePreset.thisMonth);
  DashboardData? _data;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final book = context.read<BookProvider>().currentBook;
    if (book == null) return;
    setState(() => _loading = true);
    final all = await _repo.loadTransactions(book.id);
    final invoices = await _invoiceRepo.watchInvoices(book.id).first;

    if (!mounted) return;
    final data = DashboardService.compute(
      allTransactions: all,
      range: _range,
      invoices: invoices,
      l10n: AppLocalizations.of(context),
    );
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    // showDateRangePicker used to sit here directly, seeded with
    // _range.start/_range.end as its initialDateRange. That silently broke
    // on the very first tap for most people: a preset's `end` can be after
    // today (e.g. "This Month" runs to the last calendar day, which is
    // still in the future until the month closes), and handing the picker
    // an initialDateRange outside [firstDate, lastDate] doesn't fail
    // loudly - the dialog just doesn't render a sane range. AppDateRangeDialog
    // clamps the incoming start/end into range itself, which is the fix -
    // see AppDateRangeDialog's _clamp and the same bug already hit (and
    // fixed) in the Bills section's custom-range picker.
    final picked = await AppDateRangeDialog.show(
      context,
      initialStart: _range.start,
      initialEnd: _range.end,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      title: AppLocalizations.of(context).customDateRangeTitle,
    );
    if (picked != null) {
      setState(() {
        _range = DashboardDateRange.forPreset(
          DateRangePreset.custom,
          customStart: picked.start,
          // End-of-day: DashboardDateRange.contains does an exact
          // isAfter(end) check, and a transaction dated on the selected
          // end day almost always carries a real time-of-day (new entries
          // default to DateTime.now(), not midnight) - leaving `end` at
          // the picker's midnight would silently drop same-day entries
          // from the range that's supposed to include them.
          customEnd: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
      _load();
    }
  }

  void _setPreset(DateRangePreset preset) {
    setState(() => _range = DashboardDateRange.forPreset(preset));
    _load();
  }

  /// Drill-downs recompute on the way back: the user may well have opened
  /// one of these to settle a bill, and returning to stale totals would
  /// look like the payment didn't register. (didChangeDependencies, which
  /// does the initial load, doesn't fire on pop.)
  void _openThenReload(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => mounted ? _load() : null);
  }

  /// Upcoming dues get their own short list - the Bills section has no
  /// "due soon" filter to land on.
  void _openUpcomingDue(Book book, BillDirection direction) {
    _openThenReload(DueBillsScreen(
      book: book,
      direction: direction,
      windowDays: DashboardData.upcomingDueWindowDays,
    ));
  }

  /// Overdue goes to the Bills section itself, preselected - the filter
  /// already exists there, and landing on the real screen means the user
  /// can keep working (search, switch direction, open a bill) instead of
  /// being parked in a read-only offshoot.
  ///
  /// All Time, not the usual This Month: the dashboard's overdue total is
  /// till-date, so a month-scoped list would show less than the card that
  /// opened it.
  void _openOverdueBills(BillDirection direction) {
    _openThenReload(BillListScreen(
      initialDirection: direction,
      initialStatusFilter: BillStatusFilter.overdue,
      initialRangePreset: BillDateRangePreset.allTime,
    ));
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
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(l10n.dashboardTitle(book.name))),
      body: !access.writable
          ? _buildLockedState(context, access)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildRangeSelector(),
                      const SizedBox(height: 16),
                      SummaryNumbersRow(
                        incomePaise: _data!.totalIncomePaise,
                        expensePaise: _data!.totalExpensePaise,
                        netPaise: _data!.netProfitPaise,
                      ),
                      const SizedBox(height: 20),
                      _sectionCard(
                        title: l10n.trendChartTitle,
                        child: TrendChart(points: _data!.trend),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: l10n.expenseBreakdownTitle,
                        child: ExpenseCategoryBreakdown(slices: _data!.expenseByCategory),
                      ),
                      const SizedBox(height: 16),
                      OutstandingSummaryCards(
                        totalOutstandingPaise: _data!.totalOutstandingPaise,
                        outstandingBillsCount: _data!.outstandingBillsCount,
                        totalPendingToSuppliersPaise: _data!.totalPendingToSuppliersPaise,
                        pendingSupplierBillsCount: _data!.pendingSupplierBillsCount,
                        businessCashflowPaise: _data!.businessCashflowPaise,
                        // Money owed by customers and money owed to
                        // suppliers both live in the merged Parties section
                        // now - partyType picks which sub-tab it opens on.
                        // Inside the shell these switch section in place;
                        // standalone they still push the route.
                        onTapOutstanding: () => BusinessShellScope.goTo(
                          context,
                          BusinessSection.parties,
                          partyType: ContactType.customer,
                          fallbackRoute: '/customers',
                          onReturn: () => mounted ? _load() : null,
                        ),
                        onTapPendingToSuppliers: () => BusinessShellScope.goTo(
                          context,
                          BusinessSection.parties,
                          partyType: ContactType.vendor,
                          fallbackRoute: '/suppliers',
                          onReturn: () => mounted ? _load() : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // The two "who/what is driving the business" lists sit
                      // directly under the till-date totals, so the period
                      // story (numbers -> trend -> breakdown -> totals ->
                      // who & what) reads top to bottom uninterrupted. The
                      // due/overdue alert cards follow as their own block
                      // below, rather than splitting that story in half.
                      _sectionCard(
                        title: l10n.topCustomersVendorsTitle,
                        child: _twoUp(
                          TopContactsList(
                              title: l10n.topCustomers, contacts: _data!.topCustomers),
                          TopContactsList(
                              title: l10n.topVendors, contacts: _data!.topVendors),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: l10n.fastSlowProductsTitle,
                        child: _twoUp(
                          TopProductsList(
                              title: l10n.fastMoving, products: _data!.fastMovingProducts),
                          TopProductsList(
                              title: l10n.slowMoving, products: _data!.slowMovingProducts),
                        ),
                      ),
                      const SizedBox(height: 16),
                      UpcomingDueCards(
                        upcomingPurchaseDuePaise: _data!.upcomingPurchaseDuePaise,
                        upcomingPurchaseDueCount: _data!.upcomingPurchaseDueCount,
                        upcomingSalesDuePaise: _data!.upcomingSalesDuePaise,
                        upcomingSalesDueCount: _data!.upcomingSalesDueCount,
                        onTapPurchase: () =>
                            _openUpcomingDue(book, BillDirection.purchase),
                        onTapSales: () => _openUpcomingDue(book, BillDirection.sales),
                      ),
                      const SizedBox(height: 16),
                      OverdueBillCards(
                        overduePurchasePaise: _data!.overduePurchasePaise,
                        overduePurchaseCount: _data!.overduePurchaseCount,
                        overdueSalesPaise: _data!.overdueSalesPaise,
                        overdueSalesCount: _data!.overdueSalesCount,
                        onTapPurchase: () => _openOverdueBills(BillDirection.purchase),
                        onTapSales: () => _openOverdueBills(BillDirection.sales),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  /// Two peer panels side-by-side on wide screens, stacked on a phone where
  /// two Expanded columns would squeeze each other's text to an unreadable
  /// width.
  Widget _twoUp(Widget a, Widget b) {
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(height: AppSpacing.lg), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: b),
      ],
    );
  }

  Widget _buildRangeSelector() {
    final l10n = AppLocalizations.of(context);
    final chips = [
      ChoiceChip(
        label: Text(l10n.rangeThisMonth),
        selected: _range.preset == DateRangePreset.thisMonth,
        onSelected: (_) => _setPreset(DateRangePreset.thisMonth),
      ),
      ChoiceChip(
        label: Text(l10n.rangeLastMonth),
        selected: _range.preset == DateRangePreset.lastMonth,
        onSelected: (_) => _setPreset(DateRangePreset.lastMonth),
      ),
      ChoiceChip(
        label: Text(l10n.rangeThisFinancialYear),
        selected: _range.preset == DateRangePreset.thisFinancialYear,
        onSelected: (_) => _setPreset(DateRangePreset.thisFinancialYear),
      ),
      ActionChip(
        avatar: const Icon(Icons.date_range, size: 16),
        label: Text(
            _range.preset == DateRangePreset.custom ? _range.label : l10n.rangeCustom),
        onPressed: _pickCustomRange,
      ),
    ];

    // Always one horizontally-scrollable line, on phone and desktop alike -
    // wrapping to a second line on a phone pushed the summary cards further
    // down and made the filter row's height jump depending on which preset
    // was selected (the Custom chip's label is longer than the others).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLockedState(BuildContext context, BookAccessResult access) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: context.tones.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BookAccessService.messageFor(
                  AppLocalizations.of(context), access.reason),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/settings/manage-books'),
              child: Text(AppLocalizations.of(context).switchBookOrUpgrade),
            ),
          ],
        ),
      ),
    );
  }
}
