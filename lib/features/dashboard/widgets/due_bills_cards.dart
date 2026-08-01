import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../models/dashboard_data.dart';

/// The two due-date rows on the dashboard: what's about to fall due, and
/// what's already late.
///
/// Deliberately separate from [OutstandingSummaryCards]: those are
/// till-date totals, these are time-sensitive alerts. Mixing the horizons
/// in one row would invite reading the amounts as parts of one total.

/// Purchase / Sales bills falling due within the next few days.
class UpcomingDueCards extends StatelessWidget {
  final int upcomingPurchaseDuePaise;
  final int upcomingPurchaseDueCount;
  final int upcomingSalesDuePaise;
  final int upcomingSalesDueCount;

  /// Each card drills down to the bills behind its total.
  final VoidCallback? onTapPurchase;
  final VoidCallback? onTapSales;

  const UpcomingDueCards({
    super.key,
    required this.upcomingPurchaseDuePaise,
    required this.upcomingPurchaseDueCount,
    required this.upcomingSalesDuePaise,
    required this.upcomingSalesDueCount,
    this.onTapPurchase,
    this.onTapSales,
  });

  static const _days = DashboardData.upcomingDueWindowDays;

  static String _caption(int count, String noun) =>
      count == 0 ? 'Nothing due in $_days days' : '$count $noun due in $_days days';

  @override
  Widget build(BuildContext context) {
    return _DuePairRow(
      purchase: AppStatCard(
        label: 'Upcoming Purchase Due',
        sublabel: 'To Pay',
        amountPaise: upcomingPurchaseDuePaise,
        caption: _caption(upcomingPurchaseDueCount, 'purchase bill(s)'),
        // Warning, not negative: this is a deadline approaching, not money
        // already lost - the negative tone belongs to the overdue row, so
        // the two rows stay tellable apart at a glance.
        tone: AppTone.warning,
        icon: Icons.schedule,
        onTap: onTapPurchase,
      ),
      sales: AppStatCard(
        label: 'Upcoming Sales Due',
        sublabel: 'To Collect',
        amountPaise: upcomingSalesDuePaise,
        caption: _caption(upcomingSalesDueCount, 'sales bill(s)'),
        tone: AppTone.info,
        icon: Icons.event_available,
        onTap: onTapSales,
      ),
    );
  }
}

/// Purchase / Sales bills that are past their due date and still owe money.
class OverdueBillCards extends StatelessWidget {
  final int overduePurchasePaise;
  final int overduePurchaseCount;
  final int overdueSalesPaise;
  final int overdueSalesCount;

  /// Each card drills down to the bills behind its total.
  final VoidCallback? onTapPurchase;
  final VoidCallback? onTapSales;

  const OverdueBillCards({
    super.key,
    required this.overduePurchasePaise,
    required this.overduePurchaseCount,
    required this.overdueSalesPaise,
    required this.overdueSalesCount,
    this.onTapPurchase,
    this.onTapSales,
  });

  static String _caption(int count, String noun) =>
      count == 0 ? 'Nothing overdue' : '$count $noun past due date';

  @override
  Widget build(BuildContext context) {
    return _DuePairRow(
      purchase: AppStatCard(
        label: 'Overdue Purchase Bills',
        sublabel: 'To Pay',
        amountPaise: overduePurchasePaise,
        caption: _caption(overduePurchaseCount, 'purchase bill(s)'),
        // Both cards are negative-toned regardless of direction: a missed
        // date is a missed date, whichever way the money runs.
        tone: AppTone.negative,
        icon: Icons.warning_amber_rounded,
        onTap: onTapPurchase,
      ),
      sales: AppStatCard(
        label: 'Overdue Sales Bills',
        sublabel: 'To Collect',
        amountPaise: overdueSalesPaise,
        caption: _caption(overdueSalesCount, 'sales bill(s)'),
        tone: AppTone.negative,
        icon: Icons.error_outline,
        onTap: onTapSales,
      ),
    );
  }
}

/// Purchase-then-Sales, equal height. Both rows share this so they keep the
/// same column order and metrics - two Purchase cards always sit in the
/// same column, which is what makes the pair scannable vertically.
class _DuePairRow extends StatelessWidget {
  final Widget purchase;
  final Widget sales;

  const _DuePairRow({required this.purchase, required this.sales});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight for the same reason as the other dashboard rows: this
    // sits in a ListView, so `stretch` alone would hand the children a
    // tight infinite height. See summary_numbers_row.dart.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: purchase),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: sales),
        ],
      ),
    );
  }
}
