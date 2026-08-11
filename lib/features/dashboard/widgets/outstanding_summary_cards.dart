import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../l10n/app_localizations.dart';

/// Three "till date" stat cards: money owed TO the business, money the
/// business owes suppliers, and Business Cashflow (actual received minus
/// actual paid).
///
/// Phone width: three full-width [AppStatRow]s stacked one below the other
/// instead of three [AppStatCard] tiles squeezed into one row - see
/// [AppStatRow] for why.
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
    final l10n = AppLocalizations.of(context);
    final cashflowPositive = businessCashflowPaise >= 0;
    // Composed from the same sublabel + caption keys the wide layout uses,
    // rather than duplicating them as combined strings - one translation
    // per phrase, joined here.
    final outstandingCaption = outstandingBillsCount == 0
        ? l10n.noBillsPending
        : l10n.billsPending(outstandingBillsCount);
    final pendingCaption = pendingSupplierBillsCount == 0
        ? l10n.noBillsPending
        : l10n.billsPending(pendingSupplierBillsCount);
    final outstandingDetail = '${l10n.toCollect} · $outstandingCaption';
    final pendingDetail = '${l10n.toPaySuppliers} · $pendingCaption';

    if (context.isCompact) {
      return Column(
        children: [
          AppStatRow(
            label: l10n.totalOutstanding,
            detail: outstandingDetail,
            amountPaise: totalOutstandingPaise,
            tone: AppTone.positive,
            icon: Icons.call_received,
            onTap: onTapOutstanding,
          ),
          const SizedBox(height: AppSpacing.md),
          AppStatRow(
            label: l10n.totalUnpaidBills,
            detail: pendingDetail,
            amountPaise: totalPendingToSuppliersPaise,
            tone: AppTone.negative,
            icon: Icons.call_made,
            onTap: onTapPendingToSuppliers,
          ),
          const SizedBox(height: AppSpacing.md),
          AppStatRow(
            label: l10n.businessCashflow,
            detail: '${l10n.receivedMinusPaid} · ${l10n.tillDate}',
            amountPaise: businessCashflowPaise,
            // Here the sign IS the information - a negative cashflow must
            // read as "-₹12,500", not as a bare magnitude.
            sign: MoneySign.auto,
            tone: cashflowPositive ? AppTone.positive : AppTone.negative,
            icon: cashflowPositive ? Icons.trending_up : Icons.trending_down,
          ),
        ],
      );
    }

    final toCollect = AppStatCard(
      label: l10n.totalOutstanding,
      sublabel: l10n.toCollect,
      amountPaise: totalOutstandingPaise,
      caption: outstandingCaption,
      tone: AppTone.positive,
      icon: Icons.call_received,
      onTap: onTapOutstanding,
    );

    final toPay = AppStatCard(
      label: l10n.totalUnpaidBills,
      sublabel: l10n.toPaySuppliers,
      amountPaise: totalPendingToSuppliersPaise,
      caption: pendingCaption,
      tone: AppTone.negative,
      icon: Icons.call_made,
      onTap: onTapPendingToSuppliers,
    );

    final cashflow = AppStatCard(
      label: l10n.businessCashflow,
      sublabel: l10n.receivedMinusPaid,
      amountPaise: businessCashflowPaise,
      sign: MoneySign.auto,
      caption: l10n.tillDate,
      tone: cashflowPositive ? AppTone.positive : AppTone.negative,
      icon: cashflowPositive ? Icons.trending_up : Icons.trending_down,
    );

    // IntrinsicHeight is required here (rather than bare `stretch`): this
    // row lives in a ListView, so incoming maxHeight is unbounded and
    // `stretch` alone would force a tight infinite height on the children,
    // blanking the screen. See summary_numbers_row.dart.
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
}
