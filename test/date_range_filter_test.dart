import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/widgets/app_date_range_dialog.dart';
import 'package:receipt_book/features/bills/models/bill_date_range.dart';
import 'package:receipt_book/l10n/app_localizations.dart';

/// The Bills section's custom date-range filter.
void main() {
  group('BillDateRange custom label', () {
    test('names the period for fixed presets', () {
      expect(BillDateRange.forPreset(BillDateRangePreset.thisMonth).label, 'This Month');
      expect(BillDateRange.forPreset(BillDateRangePreset.allTime).label, 'All Time');
    });

    test('states the year once when both ends share it', () {
      final range = BillDateRange.forPreset(
        BillDateRangePreset.custom,
        customStart: DateTime(2026, 8, 5),
        customEnd: DateTime(2026, 8, 12),
      );

      expect(range.label, '5 Aug – 12 Aug 2026');
    });

    test('states both years when the range spans a year boundary', () {
      final range = BillDateRange.forPreset(
        BillDateRangePreset.custom,
        customStart: DateTime(2025, 12, 28),
        customEnd: DateTime(2026, 1, 3),
      );

      expect(range.label, '28 Dec 2025 – 3 Jan 2026');
    });
  });

  group('AppDateRangeDialog', () {
    /// Pumps a host screen with an "open" button, and returns a box the
    /// dialog's result lands in once it closes.
    Future<List<DateTimeRange?>> openDialog(
      WidgetTester tester, {
      DateTime? initialStart,
      DateTime? initialEnd,
      required DateTime firstDate,
      required DateTime lastDate,
    }) async {
      final result = <DateTimeRange?>[];

      await tester.pumpWidget(
        MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result.add(await AppDateRangeDialog.show(
                    ctx,
                    initialStart: initialStart,
                    initialEnd: initialEnd,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  ));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('shows From and To fields seeded from the current range',
        (tester) async {
      final result = await openDialog(
        tester,
        initialStart: DateTime(2026, 8, 5),
        initialEnd: DateTime(2026, 8, 12),
        firstDate: DateTime(2021),
        lastDate: DateTime(2031),
      );

      expect(find.text('Custom date range'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('05 Aug 2026'), findsOneWidget);
      expect(find.text('12 Aug 2026'), findsOneWidget);
      expect(find.text('8 days selected'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result.single, isNull);
    });

    testWidgets('Apply returns the shown range', (tester) async {
      final result = await openDialog(
        tester,
        initialStart: DateTime(2026, 8, 5),
        initialEnd: DateTime(2026, 8, 12),
        firstDate: DateTime(2021),
        lastDate: DateTime(2031),
      );

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result.single!.start, DateTime(2026, 8, 5));
      expect(result.single!.end, DateTime(2026, 8, 12));
    });

    testWidgets('clamps an out-of-bounds initial range into the allowed window',
        (tester) async {
      // The All Time preset starts in 2000 - well before firstDate. Left
      // unclamped this would hand showDatePicker an illegal initialDate.
      final result = await openDialog(
        tester,
        initialStart: DateTime(2000),
        initialEnd: DateTime(2200),
        firstDate: DateTime(2021, 1, 1),
        lastDate: DateTime(2031, 12, 31),
      );

      expect(find.text('01 Jan 2021'), findsOneWidget);
      expect(find.text('31 Dec 2031'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result.single!.start, DateTime(2021, 1, 1));
      expect(result.single!.end, DateTime(2031, 12, 31));
    });

    testWidgets('a one-day range reads as "1 day selected"', (tester) async {
      await openDialog(
        tester,
        initialStart: DateTime(2026, 8, 5),
        initialEnd: DateTime(2026, 8, 5),
        firstDate: DateTime(2021),
        lastDate: DateTime(2031),
      );

      expect(find.text('1 day selected'), findsOneWidget);
    });

    testWidgets('picking a From after the To carries the To along',
        (tester) async {
      await openDialog(
        tester,
        initialStart: DateTime(2026, 8, 5),
        initialEnd: DateTime(2026, 8, 6),
        firstDate: DateTime(2026, 8, 1),
        lastDate: DateTime(2026, 8, 31),
      );

      // Open the From calendar and jump to the 20th, past the current To.
      await tester.tap(find.text('05 Aug 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Both ends now read the 20th - never From 20th / To 6th.
      expect(find.text('20 Aug 2026'), findsNWidgets(2));
      expect(find.text('1 day selected'), findsOneWidget);
    });
  });
}
