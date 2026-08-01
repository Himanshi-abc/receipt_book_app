import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';

/// Three "till date" stat cards: money owed TO the business, money the
/// business owes suppliers, and Business Cashflow (actual received minus
/// actual paid).
///
/// Three cards on one row gets tight on a narrow phone, so this switches to
/// a 2+1 layout below ~380dp rather than letting the amounts shrink to an
/// unreadable size - the numbers are the whole point of the row.
class OutstandingSummaryCards extends StatelessWidget {
  final int totalOutstandingPaise;
  final int outstandingBillsCount;
  final int totalPendingToSuppliersPaise;
  final int pendingSupplierBillsCount;
  final int businessCashflowPaise;

  /// Drill-downs: the money-owed cards open the party list that owes it.
  /// Business Cashflow has no single list behind it, so it stays inert
  /// rather than being given an arbitrary destination.
  final VoidCallback? onTapOutstanding;
  final VoidCallback? onTapPendingToSuppliers;

  const OutstandingSummaryCards({
    super.key,
    required this.totalOutstandingPaise,
    required this.outstandingBillsCount,
    required this.totalPendingToSuppliersPaise,
    required this.pendingSupplierBillsCount,
    required this.businessCashflowPaise,
    this.onTapOutstanding,
    this.onTapPendingToSuppliers,
  });

  @override
  Widget build(BuildContext context) {
    final cashflowPositive = businessCashflowPaise >= 0;

    final toCollect = AppStatCard(
      label: 'Total Outstanding',
      sublabel: 'To Collect',
      amountPaise: totalOutstandingPaise,
      caption: outstandingBillsCount == 0
          ? 'No sales bills pending'
          : '$outstandingBillsCount sales bill(s) pending',
      tone: AppTone.positive,
      icon: Icons.call_received,
      onTap: onTapOutstanding,
    );

    final toPay = AppStatCard(
      label: 'Total Unpaid Bills',
      sublabel: 'To Pay Suppliers',
      amountPaise: totalPendingToSuppliersPaise,
      caption: pendingSupplierBillsCount == 0
          ? 'No purchase bills pending'
          : '$pendingSupplierBillsCount purchase bill(s) pending',
      tone: AppTone.negative,
      icon: Icons.call_made,
      onTap: onTapPendingToSuppliers,
    );

    final cashflow = AppStatCard(
      label: 'Business Cashflow',
      sublabel: 'Received − Paid',
      amountPaise: businessCashflowPaise,
      // Here the sign IS the information - a negative cashflow must read
      // as "-₹12,500", not as a bare magnitude.
      sign: MoneySign.auto,
      caption: 'Till date',
      tone: cashflowPositive ? AppTone.positive : AppTone.negative,
      icon: cashflowPositive ? Icons.trending_up : Icons.trending_down,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;

        // IntrinsicHeight is required here (rather than bare `stretch`):
        // this row lives in a ListView, so incoming maxHeight is unbounded
        // and `stretch` alone would force a tight infinite height on the
        // children, blanking the screen. See summary_numbers_row.dart.
        if (!isNarrow) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: toCollect),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: toPay),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: cashflow),
              ],
            ),
          );
        }

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: toCollect),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: toPay),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            cashflow,
          ],
        );
      },
    );
  }
}
