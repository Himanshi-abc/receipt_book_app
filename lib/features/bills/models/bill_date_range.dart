/// Quick date-range filter for the Bills section (Sales/Purchase) - same
/// idea as a billing app's period filter (e.g. Swipe): a handful of common
/// presets plus a custom range, used to scope both the bill list and the
/// Total/Pending summary cards to the same window.
enum BillDateRangePreset {
  thisMonth,
  lastMonth,
  thisWeek,
  lastWeek,
  thisYear,
  lastYear,
  allTime,
  custom,
}

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
      case BillDateRangePreset.allTime:
        // Wide enough to hold every bill this app can create (the bill-date
        // picker itself only allows 2015-2100), so nothing is ever hidden
        // by the period filter.
        return BillDateRange(
          preset: preset,
          start: DateTime(2000),
          end: DateTime(2200),
        );
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
      case BillDateRangePreset.allTime:
        return 'All Time';
      case BillDateRangePreset.custom:
        // "5 Aug – 12 Aug 2026" rather than "5/8/2026 – 12/8/2026": this
        // label sits on the closed dropdown next to the Sales/Purchase
        // toggle, so every character it saves is width the toggle keeps.
        // The year appears once when both ends share it, and month names
        // sidestep the 5/8 vs 8/5 ambiguity.
        final sameYear = start.year == end.year;
        return '${_shortDate(start, withYear: !sameYear)} – ${_shortDate(end)}';
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime d, {bool withYear = true}) =>
      '${d.day} ${_months[d.month - 1]}${withYear ? ' ${d.year}' : ''}';

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}
