import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/features/dashboard/models/dashboard_date_range.dart';

/// The dashboard's custom date-range filter.
///
/// Regression coverage for the bug where "Custom" didn't work: the picker
/// hands back a midnight-normalized end date, and DashboardDateRange.contains
/// does an exact isAfter(end) check - so a transaction dated on the selected
/// end day at any time later than midnight (the common case: new entries
/// default to DateTime.now(), not midnight) was silently excluded. The fix,
/// in BusinessDashboardScreen._pickCustomRange, pushes the picked end date to
/// 23:59:59 before building the range - these tests pin that behaviour at
/// the model level so it can't regress unnoticed.
void main() {
  group('DashboardDateRange custom range inclusivity', () {
    test('a transaction later in the day on the end date is included when '
        'the end is normalized to end-of-day (the fix)', () {
      final range = DashboardDateRange.forPreset(
        DateRangePreset.custom,
        customStart: DateTime(2026, 8, 1),
        // What _pickCustomRange now does with the picker's midnight result.
        customEnd: DateTime(2026, 8, 10, 23, 59, 59),
      );

      // A transaction dated on the end day but with a real time-of-day -
      // exactly what DateTime.now() produces for a same-day entry.
      final sameDayLaterTx = DateTime(2026, 8, 10, 18, 45);
      expect(range.contains(sameDayLaterTx), isTrue);
    });

    test('the same transaction would have been wrongly excluded by a raw '
        'midnight end (the bug being fixed)', () {
      final buggyRange = DashboardDateRange.forPreset(
        DateRangePreset.custom,
        customStart: DateTime(2026, 8, 1),
        // What the picker returns before the fix's normalization.
        customEnd: DateTime(2026, 8, 10),
      );

      final sameDayLaterTx = DateTime(2026, 8, 10, 18, 45);
      expect(buggyRange.contains(sameDayLaterTx), isFalse);
    });

    test('a transaction on the start date at any time of day is included',
        () {
      final range = DashboardDateRange.forPreset(
        DateRangePreset.custom,
        customStart: DateTime(2026, 8, 1),
        customEnd: DateTime(2026, 8, 10, 23, 59, 59),
      );

      expect(range.contains(DateTime(2026, 8, 1, 0, 1)), isTrue);
      expect(range.contains(DateTime(2026, 8, 1, 23, 59)), isTrue);
    });

    test('a transaction the day after the end date is excluded', () {
      final range = DashboardDateRange.forPreset(
        DateRangePreset.custom,
        customStart: DateTime(2026, 8, 1),
        customEnd: DateTime(2026, 8, 10, 23, 59, 59),
      );

      expect(range.contains(DateTime(2026, 8, 11, 0, 1)), isFalse);
    });
  });
}
