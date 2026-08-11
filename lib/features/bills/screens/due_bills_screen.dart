import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import '../../invoices/services/invoice_repository.dart';
import 'bill_list_screen.dart';

/// The bills behind one dashboard "Upcoming ... Due" card.
///
/// Exists only for the upcoming buckets: the Bills section has an Overdue
/// filter to land on but no "due soon" one, so the overdue cards deep-link
/// into [BillListScreen] instead and this screen never needs that case.
///
/// Selection deliberately runs through [Invoice.isDueWithin], the same
/// predicate DashboardService uses, so this list and the card that opened it
/// can never disagree. It's a live stream rather than a snapshot passed in,
/// so paying a bill here drops it from the list immediately.
class DueBillsScreen extends StatelessWidget {
  final Book book;
  final BillDirection direction;

  /// How far ahead "upcoming" looks. Passed in rather than read from
  /// DashboardData so this stays a Bills-feature widget with no dependency
  /// on the dashboard.
  final int windowDays;

  const DueBillsScreen({
    super.key,
    required this.book,
    required this.direction,
    this.windowDays = 3,
  });

  bool get _isSales => direction == BillDirection.sales;

  String _titleOf(AppLocalizations l10n) =>
      _isSales ? l10n.upcomingSalesDue : l10n.upcomingPurchaseDue;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context);
    final title = _titleOf(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<Invoice>>(
        stream: InvoiceRepository().watchInvoices(book.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bills = snapshot.data!
              .where((i) =>
                  i.docType == InvoiceDocType.invoice &&
                  i.billDirection == direction &&
                  i.isDueWithin(windowDays, now))
              .toList()
            // Soonest due first - the one to act on today leads.
            ..sort((a, b) => a.effectiveDueDate.compareTo(b.effectiveDueDate));

          if (bills.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_available,
              title: l10n.nothingDueInNextDays(windowDays),
              message: _isSales
                  ? l10n.noSalesBillsDueInWindow
                  : l10n.noPurchaseBillsDueInWindow,
              tone: AppTone.positive,
            );
          }

          final totalPaise = bills.fold<int>(0, (a, i) => a + i.balanceDuePaise);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                ),
                child: AppStatCard(
                  label: title,
                  sublabel: _isSales ? l10n.toCollect : l10n.toPay,
                  amountPaise: totalPaise,
                  caption: l10n.billsBalanceStillOwed(bills.length),
                  tone: _isSales ? AppTone.info : AppTone.warning,
                  icon: Icons.schedule,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.xs,
                    AppSpacing.pageGutter,
                    AppSpacing.xxl,
                  ),
                  itemCount: bills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, i) {
                    final bill = bills[i];
                    return BillRow(
                      bill: bill,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoicePreviewShareScreen(invoice: bill, book: book),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
