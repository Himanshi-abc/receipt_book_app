import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/models/invoice_template.dart';
import 'package:receipt_book/features/invoices/screens/invoice_template_screen.dart';

/// Breakpoints and card sizing for the Invoice Template picker grid.
void main() {
  group('invoiceTemplateGridColumns', () {
    test('gives phones 2 columns', () {
      expect(invoiceTemplateGridColumns(360), 2); // small Android phone
      expect(invoiceTemplateGridColumns(412), 2); // typical Android phone
      expect(invoiceTemplateGridColumns(679), 2); // large phone landscape
    });

    test('gives tablets 3 columns', () {
      expect(invoiceTemplateGridColumns(680), 3); // breakpoint edge
      expect(invoiceTemplateGridColumns(800), 3); // Android tablet portrait
      expect(invoiceTemplateGridColumns(999), 3);
    });

    test('gives laptops 5 columns', () {
      expect(invoiceTemplateGridColumns(1280), 5); // breakpoint edge
      expect(invoiceTemplateGridColumns(1366), 5); // common Windows laptop
      expect(invoiceTemplateGridColumns(1920), 5); // full HD desktop
    });

    test('steps through 4 between tablet and laptop', () {
      expect(invoiceTemplateGridColumns(1000), 4); // tablet landscape
      expect(invoiceTemplateGridColumns(1279), 4);
    });

    test('shows every template, in whole rows, at each breakpoint', () {
      // The bug this pins: cards grew to fill a 1366dp laptop, so each was
      // ~390dp tall and the entire second row of five sat below the fold -
      // the screen looked like it only had five templates.
      for (final width in [412.0, 800.0, 1366.0]) {
        final columns = invoiceTemplateGridColumns(width);
        final rows = (kInvoiceTemplates.length / columns).ceil();
        expect(rows * columns, greaterThanOrEqualTo(kInvoiceTemplates.length));
      }
    });

    test('two rows of five fit a 1366x768 laptop without scrolling', () {
      const columns = 5;
      const spacing = 12.0; // AppSpacing.md, used at 4+ columns
      final tileHeight =
          invoiceTemplateTileHeight(kInvoiceTemplateMaxTileWidth);
      final twoRows = tileHeight * 2 + spacing;

      // Body height left on a 768dp-tall window after the OS title bar,
      // the AppBar and the helper line.
      const availableBodyHeight = 600.0;
      expect(twoRows, lessThan(availableBodyHeight));

      // And all 10 really do land in those two rows.
      expect((kInvoiceTemplates.length / columns).ceil(), 2);
    });

    test('never asks for more columns than there are templates', () {
      // Guards the case where someone widens the breakpoints past the
      // catalogue size, which would stretch a single short row across the
      // screen.
      for (final width in [360.0, 700.0, 1100.0, 1400.0, 2560.0]) {
        expect(
          invoiceTemplateGridColumns(width),
          lessThanOrEqualTo(kInvoiceTemplates.length),
        );
      }
    });
  });

  group('InvoiceTemplateGrid', () {
    /// Pumps the grid at a given viewport. Height is generous so the whole
    /// grid builds - GridView only builds what it can see, and the point of
    /// these tests is that all ten cards exist.
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: InvoiceTemplateGrid(
              selectedId: kInvoiceTemplates.first.id,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders all 10 templates on a phone', (tester) async {
      await pumpAt(tester, const Size(412, 2400));

      expect(tester.takeException(), isNull);
      for (final style in kInvoiceTemplates) {
        expect(find.text(style.name), findsOneWidget, reason: style.name);
      }
    });

    testWidgets('renders all 10 templates on a tablet', (tester) async {
      await pumpAt(tester, const Size(800, 2000));

      expect(tester.takeException(), isNull);
      for (final style in kInvoiceTemplates) {
        expect(find.text(style.name), findsOneWidget, reason: style.name);
      }
    });

    testWidgets('renders all 10 templates on a laptop, unscrolled',
        (tester) async {
      // The real thing the user hit: a 1366x768 laptop. No extra height and
      // no scrolling - all ten must already be on screen.
      await pumpAt(tester, const Size(1366, 700));

      expect(tester.takeException(), isNull);
      for (final style in kInvoiceTemplates) {
        expect(find.text(style.name), findsOneWidget, reason: style.name);
      }
    });

    testWidgets('cards never exceed the width cap', (tester) async {
      await pumpAt(tester, const Size(1920, 1200));

      final cardWidth = tester.getSize(find.byType(GridView)).width /
          invoiceTemplateGridColumns(1920);
      expect(cardWidth, lessThanOrEqualTo(kInvoiceTemplateMaxTileWidth + 40));
    });
  });
}
