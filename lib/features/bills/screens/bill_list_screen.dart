import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/widgets/app_date_range_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import '../models/bill_date_range.dart';
import 'create_bill_screen.dart';

/// Business Book only, standalone route (kept for any direct/deep-link
/// navigation to '/bills') - [BillsSectionBody] is what actually renders
/// this, embedded directly (no AppBar of its own) as HomeLedgerScreen's
/// default body for a Business Book.
///
/// The optional initial-state params exist for deep links that need to land
/// on a specific view - e.g. the dashboard's Overdue cards, which open this
/// screen already switched to the right direction with Overdue selected.
class BillListScreen extends StatelessWidget {
  final BillDirection initialDirection;
  final BillStatusFilter initialStatusFilter;
  final BillDateRangePreset initialRangePreset;

  const BillListScreen({
    super.key,
    this.initialDirection = BillDirection.sales,
    this.initialStatusFilter = BillStatusFilter.all,
    this.initialRangePreset = BillDateRangePreset.thisMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: BillsSectionBody(
        initialDirection: initialDirection,
        initialStatusFilter: initialStatusFilter,
        initialRangePreset: initialRangePreset,
      ),
    );
  }
}

/// All bills within a status bucket - "Pending" combines unpaid + partial,
/// since a partially paid bill still has money left outstanding.
/// "Overdue" is a subset of Pending: still owing *and* past its due date.
///
/// Public because callers deep-link into a preselected filter - see
/// [BillListScreen]'s initial-state params.
enum BillStatusFilter { all, paid, pending, overdue }

/// Sales vs Purchase bills, split by a toggle at the top - with a party
/// name search, a status filter (All/Paid/Pending/Overdue), a date-range filter
/// (This Month/Last Month/This Week/Last Week/This Year/Last Year/Custom),
/// and Total/Pending summary cards scoped to the same range - all modeled
/// after a billing app like Swipe. Returns its own Scaffold (body + FAB
/// only, no AppBar) so it can be embedded directly under someone else's
/// AppBar - see HomeLedgerScreen and [BillListScreen] above.
class BillsSectionBody extends StatefulWidget {
  /// Starting state. All three stay fully editable afterwards - these only
  /// decide what the user lands on. See [BillListScreen].
  final BillDirection initialDirection;
  final BillStatusFilter initialStatusFilter;
  final BillDateRangePreset initialRangePreset;

  const BillsSectionBody({
    super.key,
    this.initialDirection = BillDirection.sales,
    this.initialStatusFilter = BillStatusFilter.all,
    this.initialRangePreset = BillDateRangePreset.thisMonth,
  });

  @override
  State<BillsSectionBody> createState() => _BillsSectionBodyState();
}

class _BillsSectionBodyState extends State<BillsSectionBody> {
  late BillDirection _direction = widget.initialDirection;
  final _searchCtrl = TextEditingController();
  late BillStatusFilter _statusFilter = widget.initialStatusFilter;
  late BillDateRange _range = BillDateRange.forPreset(widget.initialRangePreset);

  bool get _isSales => _direction == BillDirection.sales;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    // Bills can be dated up to five years back and, via the bill form's own
    // date picker, into the future - so the filter has to reach both ways
    // or it can't select ranges that contain real bills.
    final picked = await AppDateRangeDialog.show(
      context,
      initialStart: _range.start,
      initialEnd: _range.end,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      title: 'Custom date range',
    );
    if (picked != null) {
      setState(() {
        _range = BillDateRange.forPreset(
          BillDateRangePreset.custom,
          customStart: picked.start,
          // End-of-day: a bill dated on the last day of the range must fall
          // inside it, and BillDateRange.contains compares raw DateTimes.
          customEnd: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  /// A single dropdown (top-right, next to the Sales/Purchase toggle)
  /// rather than a row of chips - "This Month" by default, every other
  /// preset (plus Custom) tucked inside the dropdown.
  Widget _buildDateRangeDropdown() {
    // A DropdownButton sizes itself to its widest item, and the custom
    // range's label is far wider than any preset's - without a cap it eats
    // the space the Sales/Purchase toggle needs on a narrow phone.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BillDateRangePreset>(
          value: _range.preset,
          isExpanded: true, // lets the label ellipsize instead of overflowing
          icon: const Icon(Icons.arrow_drop_down),
          selectedItemBuilder: (context) => BillDateRangePreset.values
              .map((p) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _range.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ))
              .toList(),
          items: BillDateRangePreset.values
              .map((p) => DropdownMenuItem(
                    value: p,
                    // Every other preset's label describes a fixed period,
                    // but Custom's label is whatever range happens to be
                    // stored - which rendered this menu entry as a
                    // meaningless pair of dates. In the list it has to name
                    // the action instead; the chosen range shows on the
                    // closed button, via selectedItemBuilder above.
                    child: p == BillDateRangePreset.custom
                        ? const Text('Custom range…')
                        : Text(BillDateRange.forPreset(p).label),
                  ))
              .toList(),
          onChanged: (preset) {
            if (preset == null) return;
            if (preset == BillDateRangePreset.custom) {
              // Reopens the dialog even when Custom is already selected -
              // DropdownButton fires onChanged on every tap, not only on a
              // change, which is what makes the range editable afterwards.
              _pickCustomRange();
            } else {
              setState(() => _range = BillDateRange.forPreset(preset));
            }
          },
        ),
      ),
    );
  }

  Widget _statusChip(String label, BillStatusFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == filter,
      onSelected: (_) => setState(() => _statusFilter = filter),
    );
  }

  Widget _buildSummaryCard(String label, int paise, AppTone tone, IconData icon) {
    return Expanded(
      child: AppStatCard(
        label: label,
        amountPaise: paise,
        tone: tone,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);

    return Scaffold(
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<BillDirection>(
                          segments: const [
                            ButtonSegment(value: BillDirection.sales, label: Text('Sales')),
                            ButtonSegment(value: BillDirection.purchase, label: Text('Purchase')),
                          ],
                          selected: {_direction},
                          onSelectionChanged: (s) => setState(() => _direction = s.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDateRangeDropdown(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Invoice>>(
                    stream: InvoiceRepository().watchInvoices(book.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final inRange = snapshot.data!
                          .where((i) =>
                              i.docType == InvoiceDocType.invoice &&
                              i.billDirection == _direction &&
                              _range.contains(i.invoiceDate))
                          .toList();

                      final totalAmountPaise =
                          inRange.fold<int>(0, (a, i) => a + i.grandTotalPaise);
                      final pendingBills =
                          inRange.where((i) => i.status != InvoiceStatus.paid).toList();
                      final pendingAmountPaise =
                          pendingBills.fold<int>(0, (a, i) => a + i.balanceDuePaise);

                      // Same Invoice.isOverdue the dashboard's overdue cards
                      // use, so this list and those totals agree.
                      final now = DateTime.now();
                      final overdueBills =
                          pendingBills.where((i) => i.isOverdue(now)).toList();

                      final statusFiltered = switch (_statusFilter) {
                        BillStatusFilter.all => inRange,
                        BillStatusFilter.paid =>
                          inRange.where((i) => i.status == InvoiceStatus.paid).toList(),
                        BillStatusFilter.pending => pendingBills,
                        // Soonest-overdue last: when you're chasing payments
                        // the most delinquent bill is the one you want first.
                        BillStatusFilter.overdue => overdueBills
                          ..sort((a, b) => a.effectiveDueDate.compareTo(b.effectiveDueDate)),
                      };

                      final query = _searchCtrl.text.trim().toLowerCase();
                      final bills = query.isEmpty
                          ? statusFiltered
                          : statusFiltered
                              .where((i) => i.customerName.toLowerCase().contains(query))
                              .toList();

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                _buildSummaryCard(
                                  _isSales ? 'Total Sales' : 'Total Purchase',
                                  totalAmountPaise,
                                  AppTone.info,
                                  _isSales
                                      ? Icons.receipt_long_outlined
                                      : Icons.inventory_2_outlined,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _buildSummaryCard(
                                  _isSales ? 'Pending to Collect' : 'Pending to Pay',
                                  pendingAmountPaise,
                                  _isSales ? AppTone.positive : AppTone.negative,
                                  _isSales ? Icons.call_received : Icons.call_made,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pageGutter),
                            child: AppSearchField(
                              controller: _searchCtrl,
                              hintText: _isSales
                                  ? 'Search by customer name'
                                  : 'Search by supplier name',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            // Wrap, not Row: a fourth chip overflows a narrow
                            // phone, and a clipped filter is an invisible one.
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusChip('All', BillStatusFilter.all),
                                _statusChip('Paid', BillStatusFilter.paid),
                                _statusChip('Pending', BillStatusFilter.pending),
                                // Count in the label because "is anything
                                // late?" is worth answering without a tap.
                                _statusChip(
                                  overdueBills.isEmpty
                                      ? 'Overdue'
                                      : 'Overdue (${overdueBills.length})',
                                  BillStatusFilter.overdue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: bills.isEmpty
                                // An empty Overdue list is good news, not a
                                // failed search - saying "try widening the
                                // filters" would read as if something's wrong.
                                ? _statusFilter == BillStatusFilter.overdue &&
                                        _searchCtrl.text.trim().isEmpty
                                    ? AppEmptyState(
                                        icon: Icons.check_circle_outline,
                                        title: 'Nothing overdue',
                                        message: _isSales
                                            ? 'Every sales bill in this date range is '
                                                'within its due date.'
                                            : 'Every purchase bill in this date range is '
                                                'within its due date.',
                                        tone: AppTone.positive,
                                      )
                                    : AppEmptyState(
                                        icon: Icons.receipt_long_outlined,
                                        title: _isSales
                                            ? 'No sales bills found'
                                            : 'No purchase bills found',
                                        message:
                                            'Nothing matches the current date range, status '
                                            'and search. Try widening one of them.',
                                      )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.pageGutter,
                                      AppSpacing.xs,
                                      AppSpacing.pageGutter,
                                      AppSpacing.giant + AppSpacing.xxl,
                                    ),
                                    itemCount: bills.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (ctx, i) {
                                      final bill = bills[i];
                                      return BillRow(
                                        bill: bill,
                                        onTap: () =>
                                            _showBillActions(context, book, bill),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: access.writable
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_isSales ? 'New Sale' : 'New Purchase'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateBillScreen(book: book, direction: _direction),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _showBillActions(BuildContext context, Book book, Invoice bill) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View Invoice'),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Invoice'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Invoice'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print Invoice'),
              onTap: () => Navigator.pop(ctx, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Invoice', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoicePreviewShareScreen(invoice: bill, book: book)),
        );
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateBillScreen(
              book: book,
              direction: bill.billDirection,
              existingInvoice: bill,
            ),
          ),
        );
        break;
      case 'share':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePreviewShareScreen(
              invoice: bill,
              book: book,
              autoAction: PreviewAutoAction.share,
            ),
          ),
        );
        break;
      case 'print':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoicePreviewShareScreen(
              invoice: bill,
              book: book,
              autoAction: PreviewAutoAction.print,
            ),
          ),
        );
        break;
      case 'delete':
        _confirmAndDelete(context, bill);
        break;
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, Invoice bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
            'Delete ${bill.invoiceNumber}? This cannot be undone. Any linked income/expense entry will be kept and must be removed separately from the ledger if needed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await InvoiceRepository().deleteInvoice(bill.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${bill.invoiceNumber} deleted.')),
      );
    }
  }

  Widget _buildLockedState(BookAccessResult access) {
    return AppEmptyState(
      icon: Icons.lock_outline,
      title: 'This book is locked',
      message: BookAccessService.messageFor(access.reason),
      tone: AppTone.warning,
      actionLabel: 'Switch Active Book / Upgrade',
      onAction: () => Navigator.pushNamed(context, '/settings/manage-books'),
    );
  }
}

/// One bill row.
///
/// The status was previously buried in a run-on subtitle
/// ("27/7/2026 · Partially Paid"). It's now a coloured badge, because
/// "which of these is still unpaid?" is the single most common question
/// asked of this list - it should be answerable by scanning, not reading.
class BillRow extends StatelessWidget {
  final Invoice bill;
  final VoidCallback onTap;

  const BillRow({super.key, required this.bill, required this.onTap});

  static ({String label, AppTone tone}) _status(InvoiceStatus s) => switch (s) {
        InvoiceStatus.paid => (label: 'Paid', tone: AppTone.positive),
        InvoiceStatus.partial => (label: 'Part paid', tone: AppTone.warning),
        InvoiceStatus.unpaid => (label: 'Unpaid', tone: AppTone.negative),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final status = _status(bill.status);
    final statusTone = tones.byTone(status.tone);
    final date = bill.invoiceDate;

    // Only meaningful while money is still owed - a paid bill's due date is
    // history, and repeating it would just dilute the row.
    final showDue = bill.status != InvoiceStatus.paid;
    final due = bill.effectiveDueDate;
    final daysLeft = bill.daysUntilDue(DateTime.now());
    // Only colored once it's actually worth acting on - a due date three
    // weeks out is reference information, not an alert.
    final dueColor = daysLeft < 0
        ? tones.byTone(AppTone.negative).fg
        : daysLeft <= 3
            ? tones.byTone(AppTone.warning).fg
            : tones.textTertiary;

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bill.customerName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${bill.invoiceNumber}  ·  '
                      '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tones.textTertiary)
                          .tabular,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showDue) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Due ${due.day.toString().padLeft(2, '0')}/'
                        '${due.month.toString().padLeft(2, '0')}/${due.year}'
                        '${daysLeft < 0 ? '  ·  Overdue' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: dueColor)
                            .tabular,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    bill.grandTotalPaise,
                    muted: true,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusTone.bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: statusTone.border),
                    ),
                    child: Text(
                      status.label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: statusTone.fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
