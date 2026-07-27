class TrendPoint {
  final DateTime bucketStart;
  final String label;
  final int incomePaise;
  final int expensePaise;

  TrendPoint({
    required this.bucketStart,
    required this.label,
    required this.incomePaise,
    required this.expensePaise,
  });
}

class CategorySlice {
  final String categoryName;
  final int amountPaise;
  CategorySlice({required this.categoryName, required this.amountPaise});
}

class ContactTotal {
  final String name;
  final int amountPaise;
  ContactTotal({required this.name, required this.amountPaise});
}

/// A product/service name plus a quantity - used for the Fast/Slow Moving
/// Products lists (quantity sold, from Sales invoice line items).
class ProductQty {
  final String name;
  final double qty;
  ProductQty({required this.name, required this.qty});
}

class DashboardData {
  final int totalIncomePaise;
  final int totalExpensePaise;
  int get netProfitPaise => totalIncomePaise - totalExpensePaise;

  final List<TrendPoint> trend;
  final List<CategorySlice> expenseByCategory; // sorted desc, top 5 taken by UI
  final List<ContactTotal> topCustomers;
  final List<ContactTotal> topVendors;

  /// Top 10 / bottom 10 products by quantity sold on Sales invoices within
  /// the selected date range (same window as the rest of the dashboard).
  final List<ProductQty> fastMovingProducts;
  final List<ProductQty> slowMovingProducts;

  /// Unpaid bills, split by direction - both "till date" (not scoped to
  /// the dashboard's selected date range, since "how much is currently
  /// outstanding" is a point-in-time fact, not a period one). Amounts are
  /// the remaining balance due, not the full invoice total, so a partially
  /// paid bill only counts what's actually still owed.
  final int totalOutstandingPaise; // unpaid/partial Sales invoices - owed TO the business
  final int outstandingBillsCount;
  final int totalPendingToSuppliersPaise; // unpaid/partial Purchase bills - owed BY the business
  final int pendingSupplierBillsCount;

  /// Also "till date", same as the pair above: total money actually
  /// received against Sales invoices and actually paid against Purchase
  /// bills (Invoice.amountReceivedPaise, summed regardless of paid/partial/
  /// unpaid status - it's real cash movement, not what's still owed).
  final int totalReceivedFromCustomersPaise;
  final int totalPaidToSuppliersPaise;

  /// "Business Cashflow": what actually moved, not what's owed. Positive
  /// means more cash came in from customers than went out to suppliers.
  int get businessCashflowPaise => totalReceivedFromCustomersPaise - totalPaidToSuppliersPaise;

  DashboardData({
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.trend,
    required this.expenseByCategory,
    required this.topCustomers,
    required this.topVendors,
    this.fastMovingProducts = const [],
    this.slowMovingProducts = const [],
    this.totalOutstandingPaise = 0,
    this.outstandingBillsCount = 0,
    this.totalPendingToSuppliersPaise = 0,
    this.pendingSupplierBillsCount = 0,
    this.totalReceivedFromCustomersPaise = 0,
    this.totalPaidToSuppliersPaise = 0,
  });

  static DashboardData empty() => DashboardData(
        totalIncomePaise: 0,
        totalExpensePaise: 0,
        trend: [],
        expenseByCategory: [],
        topCustomers: [],
        topVendors: [],
      );
}
