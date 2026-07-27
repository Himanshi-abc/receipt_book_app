/// Quick date-range filter for the Bills section (Sales/Purchase) - same
/// idea as a billing app's period filter (e.g. Swipe): a handful of common
/// presets plus a custom range, used to scope both the bill list and the
/// Total/Pending summary cards to the same window.
enum BillDateRangePreset { thisMonth, lastMonth, thisWeek, lastWeek, thisYear, lastYear, custom }

class BillDateRange {
  final BillDateRangePreset preset;
  final DateTime start;
  final DateTime end; // inclusive, end-of-day

  BillDateRange({required this.preset, required this.start, required this.end});

  static BillDateRange forPreset(
    BillDateRangePreset preset, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    switch (preset) {
      case BillDateRangePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: start, end: end);
      case BillDateRangePreset.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: start, end: end);
      case BillDateRangePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1)); // weekday: 1=Mon
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: start, end: end);
      case BillDateRangePreset.lastWeek:
        final thisMonday = now.subtract(Duration(days: now.weekday - 1));
        final lastMonday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day)
            .subtract(const Duration(days: 7));
        final end = lastMonday.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: lastMonday, end: end);
      case BillDateRangePreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: start, end: end);
      case BillDateRangePreset.lastYear:
        final start = DateTime(now.year - 1, 1, 1);
        final end = DateTime(now.year, 1, 1).subtract(const Duration(seconds: 1));
        return BillDateRange(preset: preset, start: start, end: end);
      case BillDateRangePreset.custom:
        return BillDateRange(
          preset: preset,
          start: customStart ?? DateTime(now.year, now.month, 1),
          end: customEnd ?? now,
        );
    }
  }

  String get label {
    switch (preset) {
      case BillDateRangePreset.thisMonth:
        return 'This Month';
      case BillDateRangePreset.lastMonth:
        return 'Last Month';
      case BillDateRangePreset.thisWeek:
        return 'This Week';
      case BillDateRangePreset.lastWeek:
        return 'Last Week';
      case BillDateRangePreset.thisYear:
        return 'This Year';
      case BillDateRangePreset.lastYear:
        return 'Last Year';
      case BillDateRangePreset.custom:
        return '${start.day}/${start.month}/${start.year} – ${end.day}/${end.month}/${end.year}';
    }
  }

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}
