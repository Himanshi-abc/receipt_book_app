import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/navigation/business_section.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/services/book_access_service.dart';
import '../../bills/models/bill_date_range.dart';
import '../../bills/screens/bill_list_screen.dart';
import '../../bills/screens/due_bills_screen.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
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

    final data = DashboardService.compute(
      allTransactions: all,
      range: _range,
      invoices: invoices,
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
    );
    if (picked != null) {
      setState(() {
        _range = DashboardDateRange.forPreset(
          DateRangePreset.custom,
          customStart: picked.start,
          customEnd: picked.end,
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
    final book = bookProvider.currentBook;

    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final access = bookProvider.accessFor(book);

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text('${book.name} · Dashboard')),
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
                        title: 'Income vs Expense Trend',
                        child: TrendChart(points: _data!.trend),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: 'Expense Breakdown by Category',
                        child: ExpenseCategoryBreakdown(slices: _data!.expenseByCategory),
                      ),
                      const SizedBox(height: 16),
                      OutstandingSummaryCards(
                        totalOutstandingPaise: _data!.totalOutstandingPaise,
                        outstandingBillsCount: _data!.outstandingBillsCount,
                        totalPendingToSuppliersPaise: _data!.totalPendingToSuppliersPaise,
                        pendingSupplierBillsCount: _data!.pendingSupplierBillsCount,
                        businessCashflowPaise: _data!.businessCashflowPaise,
                        // Money owed by customers lives in Customers;
                        // money owed to suppliers lives in Suppliers.
                        // Inside the shell these switch section in place;
                        // standalone they still push the route.
                        onTapOutstanding: () => BusinessShellScope.goTo(
                          context,
                          BusinessSection.customers,
                          fallbackRoute: '/customers',
                          onReturn: () => mounted ? _load() : null,
                        ),
                        onTapPendingToSuppliers: () => BusinessShellScope.goTo(
                          context,
                          BusinessSection.suppliers,
                          fallbackRoute: '/suppliers',
                          onReturn: () => mounted ? _load() : null,
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
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: 'Top Customers & Vendors',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TopContactsList(
                                  title: 'Top Customers', contacts: _data!.topCustomers),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TopContactsList(
                                  title: 'Top Vendors', contacts: _data!.topVendors),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: 'Fast Moving & Slow Moving Products',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TopProductsList(
                                  title: 'Fast Moving', products: _data!.fastMovingProducts),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TopProductsList(
                                  title: 'Slow Moving', products: _data!.slowMovingProducts),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('This Month'),
            selected: _range.preset == DateRangePreset.thisMonth,
            onSelected: (_) => _setPreset(DateRangePreset.thisMonth),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Last Month'),
            selected: _range.preset == DateRangePreset.lastMonth,
            onSelected: (_) => _setPreset(DateRangePreset.lastMonth),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('This Financial Year'),
            selected: _range.preset == DateRangePreset.thisFinancialYear,
            onSelected: (_) => _setPreset(DateRangePreset.thisFinancialYear),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(_range.preset == DateRangePreset.custom ? _range.label : 'Custom'),
            onPressed: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLockedState(BuildContext context, BookAccessResult access) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              BookAccessService.messageFor(access.reason),
              textAlign: TextAlign.center,
            ),
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
