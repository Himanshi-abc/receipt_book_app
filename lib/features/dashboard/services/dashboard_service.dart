import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
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
    int unpaidInvoicesTotalPaise = 0,
    int unpaidInvoicesCount = 0,
  }) {
    final txs = allTransactions.where((t) => range.contains(t.date)).toList();

    int totalIncome = 0;
    int totalExpense = 0;
    int outputTax = 0; // GST collected on sales (income)
    int inputTax = 0; // GST paid on purchases (expense) - input credit

    final Map<String, int> categoryTotals = {}; // categoryId/name -> paise
    final Map<String, int> customerTotals = {}; // income
    final Map<String, int> vendorTotals = {}; // expense

    for (final t in txs) {
      if (t.type == TxType.income) {
        totalIncome += t.amountPaise;
        outputTax += t.taxAmountPaise;
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
        inputTax += t.taxAmountPaise;
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

    return DashboardData(
      totalIncomePaise: totalIncome,
      totalExpensePaise: totalExpense,
      trend: _buildTrend(txs, range),
      expenseByCategory: expenseByCategory,
      topCustomers: topCustomers.take(5).toList(),
      topVendors: topVendors.take(5).toList(),
      // "Estimate only" per SRS 4.4 - real filing must reconcile against
      // actual GST returns; this is sales tax collected minus purchase
      // input tax credit for the selected period only.
      estimatedGstPayablePaise: (outputTax - inputTax).clamp(0, 1 << 62),
      unpaidInvoicesTotalPaise: unpaidInvoicesTotalPaise,
      unpaidInvoicesCount: unpaidInvoicesCount,
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
