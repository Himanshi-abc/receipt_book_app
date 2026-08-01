import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/models/invoice_model.dart';
import 'package:receipt_book/features/bills/models/bill_date_range.dart';
import 'package:receipt_book/features/dashboard/models/dashboard_date_range.dart';
import 'package:receipt_book/features/dashboard/services/dashboard_service.dart';
import 'package:receipt_book/features/dashboard/widgets/due_bills_cards.dart';
import 'package:receipt_book/features/dashboard/widgets/outstanding_summary_cards.dart';

/// Due dates on bills, and the dashboard's "upcoming due" / "overdue"
/// buckets built from them.
void main() {
  /// A bill for [amountPaise], unpaid unless [receivedPaise] says otherwise.
  Invoice bill({
    required BillDirection direction,
    required DateTime invoiceDate,
    DateTime? dueDate,
    int amountPaise = 100000,
    int receivedPaise = 0,
    InvoiceStatus status = InvoiceStatus.unpaid,
  }) {
    return Invoice(
      id: 'bill-${invoiceDate.microsecondsSinceEpoch}-${dueDate?.day}-$direction',
      bookId: 'book-1',
      billDirection: direction,
      invoiceNumber: 'INV-1',
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      customerContactId: 'contact-1',
      customerName: 'Test Party',
      customerState: 'Delhi',
      lineItems: [
        InvoiceLineItem(
          id: 'li-1',
          description: 'Item',
          qty: 1,
          rateePaise: amountPaise,
          taxRatePercent: 0,
        ),
      ],
      status: status,
      amountReceivedPaise: receivedPaise,
      createdAt: invoiceDate,
    );
  }

  group('Invoice due date', () {
    test('defaults to invoice date + 7 days when none was saved', () {
      final b = bill(
        direction: BillDirection.sales,
        invoiceDate: DateTime(2026, 8, 1),
      );

      expect(b.dueDate, isNull);
      expect(b.effectiveDueDate, DateTime(2026, 8, 8));
    });

    test('uses the saved due date when the user picked one', () {
      final b = bill(
        direction: BillDirection.sales,
        invoiceDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 9, 15),
      );

      expect(b.effectiveDueDate, DateTime(2026, 9, 15));
    });

    test('survives a toMap/fromMap round trip', () {
      final b = bill(
        direction: BillDirection.purchase,
        invoiceDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 20),
      );

      final restored = Invoice.fromMap(b.id, b.toMap());
      expect(restored.dueDate, DateTime(2026, 8, 20));
    });

    test('isDueWithin / isOverdue split unsettled bills, never both', () {
      final today = DateTime(2026, 8, 1);
      Invoice at(int inDays) => bill(
            direction: BillDirection.sales,
            invoiceDate: today,
            dueDate: today.add(Duration(days: inDays)),
          );

      expect(at(0).isDueWithin(3, today), isTrue); // due today is not late
      expect(at(0).isOverdue(today), isFalse);
      expect(at(3).isDueWithin(3, today), isTrue); // inclusive edge
      expect(at(4).isDueWithin(3, today), isFalse);
      expect(at(-1).isOverdue(today), isTrue);
      expect(at(-1).isDueWithin(3, today), isFalse);
    });

    test('a paid bill is in neither bucket', () {
      final today = DateTime(2026, 8, 1);
      final paid = bill(
        direction: BillDirection.purchase,
        invoiceDate: today,
        dueDate: today.subtract(const Duration(days: 5)),
        status: InvoiceStatus.paid,
        receivedPaise: 100000,
      );

      expect(paid.isOverdue(today), isFalse);
      expect(paid.isDueWithin(3, today), isFalse);
    });

    test('daysUntilDue counts whole days and goes negative when overdue', () {
      final b = bill(
        direction: BillDirection.sales,
        invoiceDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 10),
      );

      // Time of day must not matter - these are calendar days.
      expect(b.daysUntilDue(DateTime(2026, 8, 10, 23, 59)), 0);
      expect(b.daysUntilDue(DateTime(2026, 8, 7, 6)), 3);
      expect(b.daysUntilDue(DateTime(2026, 8, 12)), -2);
    });
  });

  group('DashboardService upcoming dues', () {
    final today = DateTime(2026, 8, 1);
    final range = DashboardDateRange.forPreset(DateRangePreset.thisMonth);

    Invoice due(BillDirection direction, int inDays, {int amountPaise = 100000}) => bill(
          direction: direction,
          invoiceDate: today,
          dueDate: today.add(Duration(days: inDays)),
          amountPaise: amountPaise,
        );

    test('counts only unpaid bills due within the next 3 days', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          due(BillDirection.purchase, 0, amountPaise: 10000), // due today
          due(BillDirection.purchase, 3, amountPaise: 20000), // edge of window
          due(BillDirection.purchase, 4, amountPaise: 99999), // just outside
          due(BillDirection.sales, 2, amountPaise: 50000),
          due(BillDirection.sales, 10, amountPaise: 99999), // far out
        ],
      );

      expect(data.upcomingPurchaseDueCount, 2);
      expect(data.upcomingPurchaseDuePaise, 30000);
      expect(data.upcomingSalesDueCount, 1);
      expect(data.upcomingSalesDuePaise, 50000);
    });

    test('excludes paid bills, and routes overdue ones to the other bucket', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          bill(
            direction: BillDirection.sales,
            invoiceDate: today,
            dueDate: today.add(const Duration(days: 1)),
            status: InvoiceStatus.paid,
            receivedPaise: 100000,
          ),
          due(BillDirection.sales, -1), // already overdue
        ],
      );

      expect(data.upcomingSalesDueCount, 0);
      expect(data.upcomingSalesDuePaise, 0);
      expect(data.overdueSalesCount, 1);
    });

    test('counts only the unpaid balance of a partly paid bill', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          bill(
            direction: BillDirection.purchase,
            invoiceDate: today,
            dueDate: today.add(const Duration(days: 2)),
            amountPaise: 100000,
            receivedPaise: 40000,
            status: InvoiceStatus.partial,
          ),
        ],
      );

      expect(data.upcomingPurchaseDueCount, 1);
      expect(data.upcomingPurchaseDuePaise, 60000);
    });

    test('picks up legacy bills that have no saved due date', () {
      // Raised 5 days ago with no due date -> defaults to +7, i.e. due in 2.
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          bill(
            direction: BillDirection.sales,
            invoiceDate: today.subtract(const Duration(days: 5)),
            amountPaise: 75000,
          ),
        ],
      );

      expect(data.upcomingSalesDueCount, 1);
      expect(data.upcomingSalesDuePaise, 75000);
    });
  });

  group('DashboardService overdue bills', () {
    final today = DateTime(2026, 8, 1);
    final range = DashboardDateRange.forPreset(DateRangePreset.thisMonth);

    Invoice due(BillDirection direction, int inDays, {int amountPaise = 100000}) => bill(
          direction: direction,
          invoiceDate: today.subtract(const Duration(days: 60)),
          dueDate: today.add(Duration(days: inDays)),
          amountPaise: amountPaise,
        );

    test('counts unpaid bills past their due date, however long ago', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          due(BillDirection.purchase, -1, amountPaise: 10000),
          due(BillDirection.purchase, -45, amountPaise: 20000), // long overdue
          due(BillDirection.sales, -2, amountPaise: 50000),
        ],
      );

      expect(data.overduePurchaseCount, 2);
      expect(data.overduePurchasePaise, 30000);
      expect(data.overdueSalesCount, 1);
      expect(data.overdueSalesPaise, 50000);
    });

    test('a bill due today is upcoming, not overdue', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: DateTime(2026, 8, 1, 18, 30), // late in the day
        invoices: [due(BillDirection.sales, 0)],
      );

      expect(data.overdueSalesCount, 0);
      expect(data.upcomingSalesDueCount, 1);
    });

    test('excludes paid bills and counts only the unpaid balance', () {
      final data = DashboardService.compute(
        allTransactions: [],
        range: range,
        now: today,
        invoices: [
          bill(
            direction: BillDirection.purchase,
            invoiceDate: today.subtract(const Duration(days: 30)),
            dueDate: today.subtract(const Duration(days: 10)),
            status: InvoiceStatus.paid,
            receivedPaise: 100000,
          ),
          bill(
            direction: BillDirection.sales,
            invoiceDate: today.subtract(const Duration(days: 30)),
            dueDate: today.subtract(const Duration(days: 10)),
            amountPaise: 100000,
            receivedPaise: 25000,
            status: InvoiceStatus.partial,
          ),
        ],
      );

      expect(data.overduePurchaseCount, 0);
      expect(data.overduePurchasePaise, 0);
      expect(data.overdueSalesCount, 1);
      expect(data.overdueSalesPaise, 75000);
    });
  });

  group('UpcomingDueCards', () {
    testWidgets('lays out inside an unbounded-height ListView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                UpcomingDueCards(
                  upcomingPurchaseDuePaise: 250000,
                  upcomingPurchaseDueCount: 2,
                  upcomingSalesDuePaise: 0,
                  upcomingSalesDueCount: 0,
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Upcoming Purchase Due'), findsOneWidget);
      expect(find.text('Upcoming Sales Due'), findsOneWidget);
      expect(find.text('2 purchase bill(s) due in 3 days'), findsOneWidget);
      expect(find.text('Nothing due in 3 days'), findsOneWidget);
    });
  });

  group('OverdueBillCards', () {
    testWidgets('lays out inside an unbounded-height ListView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                OverdueBillCards(
                  overduePurchasePaise: 125000,
                  overduePurchaseCount: 1,
                  overdueSalesPaise: 0,
                  overdueSalesCount: 0,
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Overdue Purchase Bills'), findsOneWidget);
      expect(find.text('Overdue Sales Bills'), findsOneWidget);
      expect(find.text('1 purchase bill(s) past due date'), findsOneWidget);
      expect(find.text('Nothing overdue'), findsOneWidget);
    });
  });

  group('BillDateRange.allTime', () {
    // The dashboard's Overdue cards land on this preset because their
    // totals are till-date - if it ever stopped spanning everything, those
    // lists would quietly show fewer bills than the card that opened them.
    test('contains dates well outside any other preset', () {
      final range = BillDateRange.forPreset(BillDateRangePreset.allTime);

      expect(range.contains(DateTime(2015, 1, 1)), isTrue);
      expect(range.contains(DateTime.now()), isTrue);
      expect(range.contains(DateTime(2100, 12, 31)), isTrue);
      expect(range.label, 'All Time');
    });
  });

  group('dashboard card drill-downs', () {
    /// Taps the card carrying [label] and returns without pumping a route -
    /// these assert the callback fires, not where it goes.
    Future<void> pumpAndTap(WidgetTester tester, Widget card, String label) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(padding: const EdgeInsets.all(16), children: [card]),
          ),
        ),
      );
      await tester.tap(find.text(label));
      await tester.pump();
    }

    testWidgets('outstanding cards fire their party-list callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var toCustomers = 0;
      var toSuppliers = 0;
      final card = OutstandingSummaryCards(
        totalOutstandingPaise: 500000,
        outstandingBillsCount: 2,
        totalPendingToSuppliersPaise: 250000,
        pendingSupplierBillsCount: 1,
        businessCashflowPaise: 100000,
        onTapOutstanding: () => toCustomers++,
        onTapPendingToSuppliers: () => toSuppliers++,
      );

      await pumpAndTap(tester, card, 'Total Outstanding');
      expect(toCustomers, 1);
      expect(toSuppliers, 0);

      await tester.tap(find.text('Total Unpaid Bills'));
      await tester.pump();
      expect(toSuppliers, 1);

      // Business Cashflow has no drill-down and must stay inert.
      await tester.tap(find.text('Business Cashflow'));
      await tester.pump();
      expect(toCustomers, 1);
      expect(toSuppliers, 1);
    });

    testWidgets('upcoming cards fire per-direction callbacks', (tester) async {
      var purchase = 0;
      var sales = 0;

      await pumpAndTap(
        tester,
        UpcomingDueCards(
          upcomingPurchaseDuePaise: 1000,
          upcomingPurchaseDueCount: 1,
          upcomingSalesDuePaise: 2000,
          upcomingSalesDueCount: 1,
          onTapPurchase: () => purchase++,
          onTapSales: () => sales++,
        ),
        'Upcoming Purchase Due',
      );
      expect(purchase, 1);
      expect(sales, 0);

      await tester.tap(find.text('Upcoming Sales Due'));
      await tester.pump();
      expect(sales, 1);
    });

    testWidgets('overdue cards fire per-direction callbacks', (tester) async {
      var purchase = 0;
      var sales = 0;

      await pumpAndTap(
        tester,
        OverdueBillCards(
          overduePurchasePaise: 1000,
          overduePurchaseCount: 1,
          overdueSalesPaise: 2000,
          overdueSalesCount: 1,
          onTapPurchase: () => purchase++,
          onTapSales: () => sales++,
        ),
        'Overdue Purchase Bills',
      );
      expect(purchase, 1);
      expect(sales, 0);

      await tester.tap(find.text('Overdue Sales Bills'));
      await tester.pump();
      expect(sales, 1);
    });
  });
}
