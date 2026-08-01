import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';

/// Income / Expense / Net for the selected date range.
///
/// Now three [AppStatCard]s rather than a bespoke `_NumberCard`, so this
/// row is pixel-identical to the outstanding, bills and khata summaries.
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
    final isProfit = netPaise >= 0;

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
              label: 'Income',
              amountPaise: incomePaise,
              tone: AppTone.positive,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppStatCard(
              label: 'Expense',
              amountPaise: expensePaise,
              tone: AppTone.negative,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppStatCard(
              label: isProfit ? 'Net Profit' : 'Net Loss',
              amountPaise: netPaise,
              // The label already states profit vs loss, so showing a minus
              // sign as well would read as a double negative.
              sign: MoneySign.magnitude,
              tone: isProfit ? AppTone.brand : AppTone.warning,
              icon: isProfit ? Icons.trending_up : Icons.trending_down,
            ),
          ),
        ],
      ),
    );
  }
}
