import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_book/l10n/app_localizations.dart';

import 'package:receipt_book/core/design/app_colors.dart';
import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/widgets/app_stat_card.dart';
import 'package:receipt_book/features/dashboard/widgets/outstanding_summary_cards.dart';
import 'package:receipt_book/features/dashboard/widgets/summary_numbers_row.dart';

/// Layout regression tests for the dashboard / khata summary rows.
///
/// These exist because of a real bug: a `Row` with
/// `CrossAxisAlignment.stretch` hands its children
/// `BoxConstraints.tightFor(height: constraints.maxHeight)`. Inside a
/// ListView or a Column that maxHeight is `double.infinity`, so children
/// were handed a tight *infinite* height - which throws during layout and
/// blanks the whole screen.
///
/// Neither `flutter analyze` nor a successful `flutter build` catches this:
/// it's a runtime layout failure, not a type or compile error. Pumping the
/// widget is the cheapest thing that does, so these lock it down.
void main() {
  /// Hosts [child] under the real app theme inside a ListView - i.e. with
  /// an unbounded vertical constraint, the exact condition that triggered
  /// the original failure on the Dashboard.
  Widget hostInListView(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    );
  }

  /// Same, but inside a Column - the Customers/Suppliers screen's shape.
  Widget hostInColumn(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(
          children: [Padding(padding: const EdgeInsets.all(16), child: child)],
        ),
      ),
    );
  }

  group('SummaryNumbersRow', () {
    testWidgets('lays out inside an unbounded-height ListView', (tester) async {
      await tester.pumpWidget(hostInListView(
        const SummaryNumbersRow(
          incomePaise: 1234500,
          expensePaise: 432100,
          netPaise: 802400,
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Net Profit'), findsOneWidget);
    });

    testWidgets('labels a negative net as Net Loss', (tester) async {
      await tester.pumpWidget(hostInListView(
        const SummaryNumbersRow(
          incomePaise: 100,
          expensePaise: 500,
          netPaise: -400,
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Net Loss'), findsOneWidget);
    });
  });

  group('OutstandingSummaryCards', () {
    const cards = OutstandingSummaryCards(
      totalOutstandingPaise: 5000000,
      outstandingBillsCount: 3,
      totalPendingToSuppliersPaise: 250000,
      pendingSupplierBillsCount: 1,
      businessCashflowPaise: 1200000,
    );

    testWidgets('lays out on a wide viewport (3 across)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hostInListView(cards));

      expect(tester.takeException(), isNull);
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('Total Unpaid Bills'), findsOneWidget);
      expect(find.text('Business Cashflow'), findsOneWidget);
    });

    testWidgets('lays out on a narrow (phone-width) viewport as stacked full-width cards',
        (tester) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hostInListView(cards));

      expect(tester.takeException(), isNull);
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('Total Unpaid Bills'), findsOneWidget);
      expect(find.text('Business Cashflow'), findsOneWidget);
    });
  });

  group('AppStatCard', () {
    testWidgets('equal-height row survives an unbounded parent Column',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The Customers/Suppliers summary shape: two cards side by side where
      // only one has a caption, so their natural heights differ and the row
      // genuinely has to equalise them.
      await tester.pumpWidget(hostInColumn(
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppStatCard(
                  label: 'You Collect',
                  amountPaise: 100000,
                  tone: AppTone.positive,
                  caption: 'a caption that makes this card taller',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AppStatCard(
                  label: 'You Pay',
                  amountPaise: 50000,
                  tone: AppTone.negative,
                ),
              ),
            ],
          ),
        ),
      ));

      expect(tester.takeException(), isNull);

      // Equal height is the entire reason `stretch` is used here, so assert
      // it rather than just asserting "didn't crash".
      final left = tester.getSize(
        find
            .ancestor(
              of: find.text('You Collect'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final right = tester.getSize(
        find
            .ancestor(
              of: find.text('You Pay'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(left.height, right.height);
    });

    testWidgets('renders a skeleton while loading', (tester) async {
      await tester.pumpWidget(hostInColumn(
        const AppStatCard(label: 'Loading', loading: true),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Loading'), findsOneWidget);
    });
  });
}
