import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../l10n/app_localizations.dart';
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

  /// The noun ("purchase"/"sales") used to be baked into the caption, but
  /// the card's own label already says which direction this is - so the
  /// translated caption just counts bills, and reads the same either way.
  static String _caption(AppLocalizations l10n, int count) => count == 0
      ? l10n.nothingDueInDays(_days)
      : l10n.billsDueInDays(count, _days);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DuePairRow(
      purchase: _DueCard(
        label: l10n.upcomingPurchaseDue,
        sublabel: l10n.toPay,
        amountPaise: upcomingPurchaseDuePaise,
        caption: _caption(l10n, upcomingPurchaseDueCount),
        // Warning, not negative: this is a deadline approaching, not money
        // already lost - the negative tone belongs to the overdue row, so
        // the two rows stay tellable apart at a glance.
        tone: AppTone.warning,
        icon: Icons.schedule,
        onTap: onTapPurchase,
      ),
      sales: _DueCard(
        label: l10n.upcomingSalesDue,
        sublabel: l10n.toCollect,
        amountPaise: upcomingSalesDuePaise,
        caption: _caption(l10n, upcomingSalesDueCount),
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

  static String _caption(AppLocalizations l10n, int count) =>
      count == 0 ? l10n.nothingOverdueTitle : l10n.billsPastDue(count);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DuePairRow(
      purchase: _DueCard(
        label: l10n.overduePurchaseBills,
        sublabel: l10n.toPay,
        amountPaise: overduePurchasePaise,
        caption: _caption(l10n, overduePurchaseCount),
        // Both cards are negative-toned regardless of direction: a missed
        // date is a missed date, whichever way the money runs.
        tone: AppTone.negative,
        icon: Icons.warning_amber_rounded,
        onTap: onTapPurchase,
      ),
      sales: _DueCard(
        label: l10n.overdueSalesBills,
        sublabel: l10n.toCollect,
        amountPaise: overdueSalesPaise,
        caption: _caption(l10n, overdueSalesCount),
        tone: AppTone.negative,
        icon: Icons.error_outline,
        onTap: onTapSales,
      ),
    );
  }
}

/// One card's worth of content, held as data rather than a built widget so
/// [_DuePairRow] can render it as either an [AppStatCard] (wide) or an
/// [AppStatRow] (phone) - the two shapes take the same text in different
/// slots, so the pair row has to be the one that decides.
class _DueCard {
  final String label;
  final String sublabel;
  final int amountPaise;
  final String caption;
  final AppTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  const _DueCard({
    required this.label,
    required this.sublabel,
    required this.amountPaise,
    required this.caption,
    required this.tone,
    required this.icon,
    this.onTap,
  });

  AppStatCard toCard() => AppStatCard(
        label: label,
        sublabel: sublabel,
        amountPaise: amountPaise,
        caption: caption,
        tone: tone,
        icon: icon,
        onTap: onTap,
      );

  /// The sublabel and caption join onto one line here - the tile is wide
  /// enough for both, and stacking them would make a phone card taller than
  /// it needs to be. Composed from the same two keys the wide layout uses
  /// rather than translated as a third combined string.
  AppStatRow toRow() => AppStatRow(
        label: label,
        detail: '$sublabel · $caption',
        amountPaise: amountPaise,
        tone: tone,
        icon: icon,
        onTap: onTap,
      );
}

/// Purchase-then-Sales, equal height. Both rows share this so they keep the
/// same column order and metrics - two Purchase cards always sit in the
/// same column, which is what makes the pair scannable vertically.
///
/// On a phone the pair stacks instead: two cards across 360dp leaves each
/// label ("Upcoming Purchase Due") ~150dp, which wraps to three lines and
/// still crowds the amount underneath.
class _DuePairRow extends StatelessWidget {
  final _DueCard purchase;
  final _DueCard sales;

  const _DuePairRow({required this.purchase, required this.sales});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Column(
        children: [
          purchase.toRow(),
          const SizedBox(height: AppSpacing.md),
          sales.toRow(),
        ],
      );
    }

    // IntrinsicHeight for the same reason as the other dashboard rows: this
    // sits in a ListView, so `stretch` alone would hand the children a
    // tight infinite height. See summary_numbers_row.dart.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: purchase.toCard()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: sales.toCard()),
        ],
      ),
    );
  }
}
