import '../../../core/models/transaction_model.dart';

enum DateRangePreset { thisMonth, lastMonth, thisFinancialYear, custom }

class DashboardDateRange {
  final DateRangePreset preset;
  final DateTime start;
  final DateTime end; // inclusive, end-of-day

  DashboardDateRange({required this.preset, required this.start, required this.end});

  static DashboardDateRange forPreset(DateRangePreset preset, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        return DashboardDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
        return DashboardDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.thisFinancialYear:
        // Indian FY: Apr 1 - Mar 31
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        final start = DateTime(fyStartYear, 4, 1);
        final end = DateTime(fyStartYear + 1, 4, 1).subtract(const Duration(seconds: 1));
        return DashboardDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.custom:
        return DashboardDateRange(
          preset: preset,
          start: customStart ?? DateTime(now.year, now.month, 1),
          end: customEnd ?? now,
        );
    }
  }

  String get label {
    switch (preset) {
      case DateRangePreset.thisMonth:
        return 'This Month';
      case DateRangePreset.lastMonth:
        return 'Last Month';
      case DateRangePreset.thisFinancialYear:
        return 'This Financial Year (${financialYearFor(start)})';
      case DateRangePreset.custom:
        return '${start.day}/${start.month}/${start.year} – ${end.day}/${end.month}/${end.year}';
    }
  }

  bool contains(DateTime date) =>
      !date.isBefore(start) && !date.isAfter(end);

  /// Trend chart granularity: daily for short ranges, weekly for medium,
  /// monthly for a full financial year - keeps the chart readable.
  int get spanDays => end.difference(start).inDays + 1;
}
