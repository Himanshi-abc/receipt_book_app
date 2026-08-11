import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../l10n/app_localizations.dart';

/// Income / Expense / Net for the selected date range.
///
/// Now three [AppStatCard]s rather than a bespoke `_NumberCard`, so this
/// row is pixel-identical to the outstanding, bills and khata summaries.
///
/// Phone width collapses to three stacked [AppStatRow]s, matching
/// [OutstandingSummaryCards] - these are the first numbers on the dashboard
/// and the ones most likely to be a long amount (a whole month's income), so
/// they're exactly the wrong three to squeeze into one 360dp row.
class SummaryNumbersRow extends StatelessWidget {
  final int incomePaise;
  final int expensePaise;
  final int netPaise;

  const SummaryNumbersRow({
    super.key,
    required this.incomePaise,
    required this.expensePaise,
    required this.netPaise,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isProfit = netPaise >= 0;
    final netLabel = isProfit ? l10n.netProfit : l10n.netLoss;
    final netTone = isProfit ? AppTone.brand : AppTone.warning;
    final netIcon = isProfit ? Icons.trending_up : Icons.trending_down;

    if (context.isCompact) {
      return Column(
        children: [
          AppStatRow(
            label: l10n.typeIncome,
            amountPaise: incomePaise,
            tone: AppTone.positive,
            icon: Icons.arrow_downward,
          ),
          const SizedBox(height: AppSpacing.md),
          AppStatRow(
            label: l10n.typeExpense,
            amountPaise: expensePaise,
            tone: AppTone.negative,
            icon: Icons.arrow_upward,
          ),
          const SizedBox(height: AppSpacing.md),
          AppStatRow(
            label: netLabel,
            amountPaise: netPaise,
            // Same reasoning as the wide layout below: the label already
            // says profit vs loss.
            sign: MoneySign.magnitude,
            tone: netTone,
            icon: netIcon,
          ),
        ],
      );
    }

    // IntrinsicHeight, not `CrossAxisAlignment.stretch`: this row sits in a
    // ListView, so its incoming maxHeight is unbounded. `stretch` would
    // hand children a tight *infinite* height and the subtree would fail to
    // lay out. IntrinsicHeight resolves a finite height (the tallest card)
    // first, which is what actually makes the three cards equal height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppStatCard(
              label: l10n.typeIncome,
              amountPaise: incomePaise,
              tone: AppTone.positive,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppStatCard(
              label: l10n.typeExpense,
              amountPaise: expensePaise,
              tone: AppTone.negative,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppStatCard(
              label: netLabel,
              amountPaise: netPaise,
              // The label already states profit vs loss, so showing a minus
              // sign as well would read as a double negative.
              sign: MoneySign.magnitude,
              tone: netTone,
              icon: netIcon,
            ),
          ),
        ],
      ),
    );
  }
}
