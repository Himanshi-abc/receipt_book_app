import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../../core/utils/money.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import 'create_bill_screen.dart';

/// Replaces the old Invoices section: same GST document/repository
/// underneath, now split into Sales (money in, from Customers) and
/// Purchase (money out, to Suppliers) with a toggle at the top.
class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  BillDirection _direction = BillDirection.sales;

  bool get _isSales => _direction == BillDirection.sales;

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SegmentedButton<BillDirection>(
                    segments: const [
                      ButtonSegment(value: BillDirection.sales, label: Text('Sales')),
                      ButtonSegment(value: BillDirection.purchase, label: Text('Purchase')),
                    ],
                    selected: {_direction},
                    onSelectionChanged: (s) => setState(() => _direction = s.first),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Invoice>>(
                    stream: InvoiceRepository().watchInvoices(book.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final bills = snapshot.data!
                          .where((i) =>
                              i.docType == InvoiceDocType.invoice && i.billDirection == _direction)
                          .toList();
                      if (bills.isEmpty) {
                        return Center(
                          child: Text(_isSales
                              ? 'No sales bills yet. Tap + to create one.'
                              : 'No purchase bills yet. Tap + to create one.'),
                        );
                      }
                      return ListView.builder(
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InvoicePreviewShareScreen(invoice: bill, book: book),
                              ),
                            ),
                          );
                        },
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
