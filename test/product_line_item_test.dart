import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/models/invoice_model.dart';
import 'package:receipt_book/core/models/product_model.dart';
import 'package:receipt_book/core/utils/tax_math.dart';
import 'package:receipt_book/features/bills/screens/product_line_item_screen.dart';

/// The screen shown between picking a product and adding it to a bill.
void main() {
  Product product({
    String name = 'Steel Bolt',
    int pricePaise = 100000, // Rs 1,000
    bool includesTax = false,
    double taxRate = 18,
    String? unit,
  }) {
    final now = DateTime(2026, 8, 1);
    return Product(
      id: 'p1',
      bookId: 'b1',
      name: name,
      type: ProductItemType.product,
      sellingPricePaise: pricePaise,
      priceIncludesTax: includesTax,
      taxRatePercent: taxRate,
      hsnCode: '7318',
      unit: unit,
      productCode: 7,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<InvoiceLineItem?> pumpAndAdd(
    WidgetTester tester,
    Product p, {
    Future<void> Function(WidgetTester tester)? interact,
    bool tapAdd = true,
  }) async {
    InvoiceLineItem? result;

    // Tall enough that the quantity stepper and the buttons are on screen -
    // the default 800x600 test viewport cuts the form off partway down and
    // taps on off-screen widgets fail.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await Navigator.push<InvoiceLineItem>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ProductLineItemScreen(product: p),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    if (interact != null) await interact(tester);

    if (tapAdd) {
      await tester.tap(find.text('Add to Bill'));
      await tester.pumpAndSettle();
    }
    return result;
  }

  /// The field carrying [label], for entering text into.
  Finder fieldWithLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextField),
      );

  group('opening state', () {
    testWidgets('an exclusive-priced product fills both bases', (tester) async {
      await pumpAndAdd(tester, product(pricePaise: 100000), tapAdd: false);

      expect(find.text('Steel Bolt'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1000'), findsOneWidget); // ex-tax
      expect(find.widgetWithText(TextField, '1180'), findsOneWidget); // incl.
    });

    testWidgets('an inclusive-priced product is converted back to ex-tax',
        (tester) async {
      // Stored as Rs 1,180 including 18% - the ex-tax basis is Rs 1,000.
      await pumpAndAdd(
        tester,
        product(pricePaise: 118000, includesTax: true),
        tapAdd: false,
      );

      expect(find.widgetWithText(TextField, '1000'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1180'), findsOneWidget);
    });

    testWidgets('a zero-tax product shows the same figure on both lines',
        (tester) async {
      await pumpAndAdd(
        tester,
        product(pricePaise: 50000, taxRate: 0),
        tapAdd: false,
      );

      expect(find.widgetWithText(TextField, '500'), findsNWidgets(2));
      expect(
        find.text('This item is not taxed, so both prices are the same.'),
        findsOneWidget,
      );
    });

    testWidgets('quantity starts at 1', (tester) async {
      await pumpAndAdd(tester, product(), tapAdd: false);
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
    });
  });

  group('two-way price editing', () {
    testWidgets('typing an ex-tax price updates the with-tax price',
        (tester) async {
      final line = await pumpAndAdd(
        tester,
        product(),
        interact: (t) async {
          await t.enterText(fieldWithLabel('Price without tax (₹)'), '2000');
          await t.pumpAndSettle();
          // 2000 + 18% = 2360
          expect(find.widgetWithText(TextField, '2360'), findsOneWidget);
        },
      );

      expect(line!.rateePaise, 200000);
    });

    testWidgets('typing a with-tax price stores the ex-tax basis',
        (tester) async {
      // The whole point: someone who agreed "1180 all-in" types 1180 and the
      // invoice still carries 1000 + 180 tax.
      final line = await pumpAndAdd(
        tester,
        product(),
        interact: (t) async {
          await t.enterText(fieldWithLabel('Price with tax (₹)'), '1180');
          await t.pumpAndSettle();
        },
      );

      expect(line!.rateePaise, 100000);
      expect(line.taxAmountPaise, 18000);
      expect(line.totalAmountPaise, 118000);
    });

    testWidgets('the tax rate is not offered as a choice', (tester) async {
      // Tax is a one-time decision at Products > Add/Edit, not a per-sale
      // one - there should be nothing on this screen to tap to change it.
      await pumpAndAdd(tester, product(taxRate: 18), tapAdd: false);

      expect(find.text('Tax rate'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      // Stated, not offered: it shows up in the header line ("Code 7 ·
      // HSN 7318 · 18% tax") and in the with-tax field's helper text, but
      // there is nothing here to tap to change it.
      expect(find.textContaining('18% tax'), findsAtLeastNWidgets(1));
    });

    testWidgets('the fixed rate still drives both price fields', (tester) async {
      await pumpAndAdd(tester, product(taxRate: 5), tapAdd: false);

      // 5%, not the default 18% used elsewhere in this file - the
      // with-tax field is computed from whatever rate the product carries.
      expect(find.widgetWithText(TextField, '1050'), findsOneWidget);
    });
  });

  group('quantity', () {
    testWidgets('the stepper raises quantity and the total follows',
        (tester) async {
      final line = await pumpAndAdd(
        tester,
        product(),
        interact: (t) async {
          await t.tap(find.byIcon(Icons.add));
          await t.pumpAndSettle();
          await t.tap(find.byIcon(Icons.add));
          await t.pumpAndSettle();
        },
      );

      expect(line!.qty, 3);
      expect(line.totalAmountPaise, 354000); // 3 x 1180
    });

    testWidgets('a typed decimal quantity is kept', (tester) async {
      final line = await pumpAndAdd(
        tester,
        product(unit: 'kg'),
        interact: (t) async {
          await t.enterText(find.widgetWithText(TextField, '1'), '2.5');
          await t.pumpAndSettle();
        },
      );

      expect(line!.qty, 2.5);
      expect(line.taxableAmountPaise, 250000);
    });

    testWidgets('the decrease button is disabled at a quantity of 1',
        (tester) async {
      await pumpAndAdd(tester, product(), tapAdd: false);

      final minus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.remove),
          matching: find.byType(IconButton),
        ),
      );
      expect(minus.onPressed, isNull);
    });
  });

  group('guards', () {
    testWidgets('Add is disabled until there is a price', (tester) async {
      await pumpAndAdd(
        tester,
        product(pricePaise: 0),
        tapAdd: false,
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add to Bill'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Cancel returns nothing', (tester) async {
      final line = await pumpAndAdd(
        tester,
        product(),
        tapAdd: false,
        interact: (t) async {
          await t.tap(find.text('Cancel'));
          await t.pumpAndSettle();
        },
      );

      expect(line, isNull);
    });
  });

  group('tax_math round trip', () {
    test('exclusive -> inclusive -> exclusive is stable at common rates', () {
      for (final rate in [0.0, 5.0, 12.0, 18.0, 28.0]) {
        for (final paise in [100000, 45999, 1, 7350]) {
          final inclusive = inclusiveFromExclusive(paise, rate);
          expect(
            exclusiveFromInclusive(inclusive, rate),
            closeTo(paise, 1),
            reason: 'rate $rate, paise $paise',
          );
        }
      }
    });
  });
}
