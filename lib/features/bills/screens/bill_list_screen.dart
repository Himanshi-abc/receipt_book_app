import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../../core/utils/money.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import '../models/bill_date_range.dart';
import 'create_bill_screen.dart';

/// Business Book only, standalone route (kept for any direct/deep-link
/// navigation to '/bills') - [BillsSectionBody] is what actually renders
/// this, embedded directly (no AppBar of its own) as HomeLedgerScreen's
/// default body for a Business Book.
class BillListScreen extends StatelessWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: const BillsSectionBody(),
    );
  }
}

/// All bills within a status bucket - "Pending" combines unpaid + partial,
/// since a partially paid bill still has money left outstanding.
enum _StatusFilter { all, paid, pending }

/// Sales vs Purchase bills, split by a toggle at the top - with a party
/// name search, a status filter (All/Paid/Pending), a date-range filter
/// (This Month/Last Month/This Week/Last Week/This Year/Last Year/Custom),
/// and Total/Pending summary cards scoped to the same range - all modeled
/// after a billing app like Swipe. Returns its own Scaffold (body + FAB
/// only, no AppBar) so it can be embedded directly under someone else's
/// AppBar - see HomeLedgerScreen and [BillListScreen] above.
class BillsSectionBody extends StatefulWidget {
  const BillsSectionBody({super.key});

  @override
  State<BillsSectionBody> createState() => _BillsSectionBodyState();
}

class _BillsSectionBodyState extends State<BillsSectionBody> {
  BillDirection _direction = BillDirection.sales;
  final _searchCtrl = TextEditingController();
  _StatusFilter _statusFilter = _StatusFilter.all;
  BillDateRange _range = BillDateRange.forPreset(BillDateRangePreset.thisMonth);

  bool get _isSales => _direction == BillDirection.sales;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    // Presets like "This Month"/"This Year" run through the end of the
    // period, which can be *after* today - clamp before handing it to the
    // picker as initialDateRange, since showDateRangePicker requires it to
    // fall within [firstDate, lastDate] or it renders an incorrect,
    // silently-clamped range instead of what the current filter actually is.
    var initialStart = _range.start.isBefore(firstDate) ? firstDate : _range.start;
    final initialEnd = _range.end.isAfter(now) ? now : _range.end;
    if (initialStart.isAfter(initialEnd)) initialStart = initialEnd;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked != null) {
      setState(() {
        _range = BillDateRange.forPreset(
          BillDateRangePreset.custom,
          customStart: picked.start,
          customEnd: picked.end,
        );
      });
    }
  }

  /// A single dropdown (top-right, next to the Sales/Purchase toggle)
  /// rather than a row of chips - "This Month" by default, every other
  /// preset (plus Custom) tucked inside the dropdown.
  Widget _buildDateRangeDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<BillDateRangePreset>(
        value: _range.preset,
        icon: const Icon(Icons.arrow_drop_down),
        selectedItemBuilder: (context) => BillDateRangePreset.values
            .map((p) => Align(
                  alignment: Alignment.centerRight,
                  child: Text(_range.label, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        items: BillDateRangePreset.values
            .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(BillDateRange.forPreset(p).label),
                ))
            .toList(),
        onChanged: (preset) {
          if (preset == null) return;
          if (preset == BillDateRangePreset.custom) {
            _pickCustomRange();
          } else {
            setState(() => _range = BillDateRange.forPreset(preset));
          }
        },
      ),
    );
  }

  Widget _buildSummaryCard(String label, int paise, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              Money.format(paise),
              style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

                      final statusFiltered = switch (_statusFilter) {
                        _StatusFilter.all => inRange,
                        _StatusFilter.paid =>
                          inRange.where((i) => i.status == InvoiceStatus.paid).toList(),
                        _StatusFilter.pending => pendingBills,
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
                                  Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                _buildSummaryCard(
                                  _isSales ? 'Pending to Collect' : 'Pending to Pay',
                                  pendingAmountPaise,
                                  _isSales ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: _isSales
                                    ? 'Search by customer name'
                                    : 'Search by supplier name',
                                prefixIcon: const Icon(Icons.search),
                                border:
                                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected: _statusFilter == _StatusFilter.all,
                                  onSelected: (_) =>
                                      setState(() => _statusFilter = _StatusFilter.all),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Paid'),
                                  selected: _statusFilter == _StatusFilter.paid,
                                  onSelected: (_) =>
                                      setState(() => _statusFilter = _StatusFilter.paid),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Pending'),
                                  selected: _statusFilter == _StatusFilter.pending,
                                  onSelected: (_) =>
                                      setState(() => _statusFilter = _StatusFilter.pending),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: bills.isEmpty
                                ? Center(
                                    child: Text(_isSales
                                        ? 'No sales bills found.'
                                        : 'No purchase bills found.'),
                                  )
                                : ListView.builder(
                                    itemCount: bills.length,
                                    itemBuilder: (ctx, i) {
                                      final bill = bills[i];
                                      return ListTile(
                                        title: Text('${bill.invoiceNumber} — ${bill.customerName}'),
                                        subtitle: Text(
                                            '${bill.invoiceDate.day}/${bill.invoiceDate.month}/${bill.invoiceDate.year} · ${_statusLabel(bill.status)}'),
                                        trailing: Text(
                                          Money.format(bill.grandTotalPaise),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        onTap: () => _showBillActions(context, book, bill),
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

  String _statusLabel(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.unpaid:
        return 'Unpaid';
      case InvoiceStatus.partial:
        return 'Partially Paid';
    }
  }

  Widget _buildLockedState(BookAccessResult access) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(BookAccessService.messageFor(access.reason), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/settings/manage-books'),
              child: const Text('Switch Active Book / Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
