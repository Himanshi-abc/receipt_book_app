import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/invoice_model.dart';
import '../models/dashboard_date_range.dart';
import '../models/dashboard_data.dart';

enum TrendGranularity { daily, weekly, monthly }

/// Pure aggregation logic, kept separate from Firestore/SQLite so it's
/// trivially unit-testable: feed it a list of transactions, get back
/// exactly what the dashboard renders.
class DashboardService {
  DashboardService._();

  static DashboardData compute({
    required List<AppTransaction> allTransactions,
    required DashboardDateRange range,
    List<Category> categories = const [],
    List<Invoice> invoices = const [],
    /// "Today" for the upcoming-due window. Injectable so the computation
    /// stays a pure function of its inputs (and testable without clocks).
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final txs = allTransactions.where((t) => range.contains(t.date)).toList();

    int totalIncome = 0;
    int totalExpense = 0;

    final Map<String, int> categoryTotals = {}; // categoryId/name -> paise
    final Map<String, int> customerTotals = {}; // income
    final Map<String, int> vendorTotals = {}; // expense

    for (final t in txs) {
      if (t.type == TxType.income) {
        totalIncome += t.amountPaise;
        if (t.vendorOrCustomerName.isNotEmpty) {
          customerTotals[t.vendorOrCustomerName] =
              (customerTotals[t.vendorOrCustomerName] ?? 0) + t.amountPaise;
        }
      } else {
        // If business_use_percent is set, only that share counts toward
        // business expense/profit reporting (SRS 4.2's "part personal use").
        final businessShare = t.businessUsePercent != null
            ? (t.amountPaise * t.businessUsePercent! / 100).round()
            : t.amountPaise;
        totalExpense += businessShare;
        if (t.vendorOrCustomerName.isNotEmpty) {
          vendorTotals[t.vendorOrCustomerName] =
              (vendorTotals[t.vendorOrCustomerName] ?? 0) + businessShare;
        }
        final catName = _categoryName(t.categoryId, categories);
        categoryTotals[catName] = (categoryTotals[catName] ?? 0) + businessShare;
      }
    }

    final expenseByCategory = categoryTotals.entries
        .map((e) => CategorySlice(categoryName: e.key, amountPaise: e.value))
        .toList()
      ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));

    final topCustomers = customerTotals.entries
        .map((e) => ContactTotal(name: e.key, amountPaise: e.value))
        .toList()
      ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));

    final topVendors = vendorTotals.entries
        .map((e) => ContactTotal(name: e.key, amountPaise: e.value))
        .toList()
      ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));

    // Unpaid bills, split by direction - "till date", not range-scoped
    // (see DashboardData's doc comment for why).
    final invoiceDocs = invoices.where((i) => i.docType == InvoiceDocType.invoice);
    final allSales = invoiceDocs.where((i) => i.billDirection == BillDirection.sales).toList();
    final allPurchase =
        invoiceDocs.where((i) => i.billDirection == BillDirection.purchase).toList();
    final unpaidSales = allSales.where((i) => i.status != InvoiceStatus.paid).toList();
    final unpaidPurchase = allPurchase.where((i) => i.status != InvoiceStatus.paid).toList();
    final totalOutstanding = unpaidSales.fold<int>(0, (a, i) => a + i.balanceDuePaise);
    final totalPendingToSuppliers = unpaidPurchase.fold<int>(0, (a, i) => a + i.balanceDuePaise);

    // "Business Cashflow" - actual cash received/paid, till date, regardless
    // of a bill's paid/partial/unpaid status (see DashboardData.
    // businessCashflowPaise).
    final totalReceivedFromCustomers =
        allSales.fold<int>(0, (a, i) => a + i.amountReceivedPaise);
    final totalPaidToSuppliers = allPurchase.fold<int>(0, (a, i) => a + i.amountReceivedPaise);

    // Upcoming vs overdue. The predicates live on Invoice so the drill-down
    // list these cards open (DueBillsScreen) selects exactly the same bills
    // these totals were computed from - two copies of the rule would
    // eventually disagree, and a card whose total doesn't match its own
    // list is worse than no card.
    const window = DashboardData.upcomingDueWindowDays;
    final upcomingSales = unpaidSales.where((i) => i.isDueWithin(window, today)).toList();
    final upcomingPurchase = unpaidPurchase.where((i) => i.isDueWithin(window, today)).toList();
    final overdueSales = unpaidSales.where((i) => i.isOverdue(today)).toList();
    final overduePurchase = unpaidPurchase.where((i) => i.isOverdue(today)).toList();

    // Fast/Slow Moving Products - quantity sold on Sales invoices within
    // the selected date range, grouped by line-item description (already
    // denormalized onto the line item, so no Product join is needed).
    final Map<String, double> qtyByProduct = {};
    for (final inv in invoices) {
      if (inv.docType != InvoiceDocType.invoice) continue;
      if (inv.billDirection != BillDirection.sales) continue;
      if (!range.contains(inv.invoiceDate)) continue;
      for (final li in inv.lineItems) {
        final name = li.description.trim();
        if (name.isEmpty) continue;
        qtyByProduct[name] = (qtyByProduct[name] ?? 0) + li.qty;
      }
    }
    final rankedByQty = qtyByProduct.entries
        .map((e) => ProductQty(name: e.key, qty: e.value))
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return DashboardData(
      totalIncomePaise: totalIncome,
      totalExpensePaise: totalExpense,
      trend: _buildTrend(txs, range),
      expenseByCategory: expenseByCategory,
      topCustomers: topCustomers.take(5).toList(),
      topVendors: topVendors.take(5).toList(),
      fastMovingProducts: rankedByQty.take(10).toList(),
      slowMovingProducts: rankedByQty.reversed.take(10).toList(),
      totalOutstandingPaise: totalOutstanding,
      outstandingBillsCount: unpaidSales.length,
      totalPendingToSuppliersPaise: totalPendingToSuppliers,
      pendingSupplierBillsCount: unpaidPurchase.length,
      totalReceivedFromCustomersPaise: totalReceivedFromCustomers,
      totalPaidToSuppliersPaise: totalPaidToSuppliers,
      upcomingPurchaseDuePaise:
          upcomingPurchase.fold<int>(0, (a, i) => a + i.balanceDuePaise),
      upcomingPurchaseDueCount: upcomingPurchase.length,
      upcomingSalesDuePaise: upcomingSales.fold<int>(0, (a, i) => a + i.balanceDuePaise),
      upcomingSalesDueCount: upcomingSales.length,
      overduePurchasePaise: overduePurchase.fold<int>(0, (a, i) => a + i.balanceDuePaise),
      overduePurchaseCount: overduePurchase.length,
      overdueSalesPaise: overdueSales.fold<int>(0, (a, i) => a + i.balanceDuePaise),
      overdueSalesCount: overdueSales.length,
    );
  }

  static String _categoryName(String? categoryId, List<Category> categories) {
    if (categoryId == null) return 'Uncategorized';
    final fromCustom = categories.where((c) => c.id == categoryId);
    if (fromCustom.isNotEmpty) return fromCustom.first.name;
    final fromDefaults = Category.systemDefaults().where((c) => c.id == categoryId);
    if (fromDefaults.isNotEmpty) return fromDefaults.first.name;
    return 'Uncategorized';
  }

  static TrendGranularity _granularityFor(DashboardDateRange range) {
    if (range.spanDays <= 31) return TrendGranularity.daily;
    if (range.spanDays <= 120) return TrendGranularity.weekly;
    return TrendGranularity.monthly;
  }

  static List<TrendPoint> _buildTrend(List<AppTransaction> txs, DashboardDateRange range) {
    final granularity = _granularityFor(range);
    final Map<DateTime, TrendPoint> buckets = {};

    DateTime bucketKeyFor(DateTime date) {
      switch (granularity) {
        case TrendGranularity.daily:
          return DateTime(date.year, date.month, date.day);
        case TrendGranularity.weekly:
          final weekday = date.weekday; // 1=Mon
          final monday = date.subtract(Duration(days: weekday - 1));
          return DateTime(monday.year, monday.month, monday.day);
        case TrendGranularity.monthly:
          return DateTime(date.year, date.month, 1);
      }
    }

    String labelFor(DateTime key) {
      switch (granularity) {
        case TrendGranularity.daily:
          return '${key.day}/${key.month}';
        case TrendGranularity.weekly:
          return 'W/${key.day}/${key.month}';
        case TrendGranularity.monthly:
          const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          return months[key.month - 1];
      }
    }

    for (final t in txs) {
      final key = bucketKeyFor(t.date);
      final existing = buckets[key];
      final businessShare = (t.type == TxType.expense && t.businessUsePercent != null)
          ? (t.amountPaise * t.businessUsePercent! / 100).round()
          : t.amountPaise;
      if (existing == null) {
        buckets[key] = TrendPoint(
          bucketStart: key,
          label: labelFor(key),
          incomePaise: t.type == TxType.income ? businessShare : 0,
          expensePaise: t.type == TxType.expense ? businessShare : 0,
        );
      } else {
        buckets[key] = TrendPoint(
          bucketStart: key,
          label: existing.label,
          incomePaise: existing.incomePaise + (t.type == TxType.income ? businessShare : 0),
          expensePaise: existing.expensePaise + (t.type == TxType.expense ? businessShare : 0),
        );
      }
    }

    final points = buckets.values.toList()
      ..sort((a, b) => a.bucketStart.compareTo(b.bucketStart));
    return points;
  }
}
