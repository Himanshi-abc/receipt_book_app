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

class DashboardData {
  final int totalIncomePaise;
  final int totalExpensePaise;
  int get netProfitPaise => totalIncomePaise - totalExpensePaise;

  final List<TrendPoint> trend;
  final List<CategorySlice> expenseByCategory; // sorted desc, top 5 taken by UI
  final List<ContactTotal> topCustomers;
  final List<ContactTotal> topVendors;

  /// SRS 4.4: "Estimated GST payable (sales tax collected minus purchase
  /// tax paid) - clearly labeled 'estimate only'."
  final int estimatedGstPayablePaise;

  /// SRS 4.4: unpaid invoices total + count. Zero until the Invoice
  /// Generator (with its own Invoice model) is built - wired here so the
  /// dashboard UI doesn't need to change when that lands.
  final int unpaidInvoicesTotalPaise;
  final int unpaidInvoicesCount;

  DashboardData({
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.trend,
    required this.expenseByCategory,
    required this.topCustomers,
    required this.topVendors,
    required this.estimatedGstPayablePaise,
    this.unpaidInvoicesTotalPaise = 0,
    this.unpaidInvoicesCount = 0,
  });

  static DashboardData empty() => DashboardData(
        totalIncomePaise: 0,
        totalExpensePaise: 0,
        trend: [],
        expenseByCategory: [],
        topCustomers: [],
        topVendors: [],
        estimatedGstPayablePaise: 0,
      );
}
