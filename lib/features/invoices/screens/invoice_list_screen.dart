import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../books/providers/book_provider.dart';
import '../services/invoice_repository.dart';
import '../../../core/utils/money.dart';
import 'create_edit_invoice_screen.dart';
import 'invoice_preview_share_screen.dart';

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: !access.writable
          ? _buildLockedState(context, access)
          : StreamBuilder<List<Invoice>>(
              stream: InvoiceRepository().watchInvoices(book.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final invoices = snapshot.data!
                    .where((i) => i.docType == InvoiceDocType.invoice)
                    .toList();
                if (invoices.isEmpty) {
                  return const Center(child: Text('No invoices yet. Tap + to create one.'));
                }
                return ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (ctx, i) {
                    final inv = invoices[i];
                    return ListTile(
                      title: Text('${inv.invoiceNumber} — ${inv.customerName}'),
                      subtitle: Text(
                          '${inv.invoiceDate.day}/${inv.invoiceDate.month}/${inv.invoiceDate.year} · ${_statusLabel(inv.status)}'),
                      trailing: Text(
                        Money.format(inv.grandTotalPaise),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoicePreviewShareScreen(invoice: inv, book: book),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: access.writable
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateEditInvoiceScreen(book: book)),
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

  Widget _buildLockedState(BuildContext context, BookAccessResult access) {
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
