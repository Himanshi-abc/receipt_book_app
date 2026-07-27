import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/utils/money.dart';
import '../services/invoice_pdf_service.dart';
import '../services/invoice_repository.dart';

/// Which action (if any) to fire automatically once the PDF is generated -
/// lets the bill list's "Share Invoice" / "Print Invoice" menu entries jump
/// straight to that action instead of making the user tap it again from
/// inside the preview.
enum PreviewAutoAction { none, share, print }

/// SRS 4.5: "Generate a clean PDF invoice... Share button -> opens native
/// share sheet... just use the OS share sheet, no need to build custom
/// WhatsApp integration." The `printing` package's PdfPreview widget gives
/// us the preview pane AND wires straight into `Printing.sharePdf`, which
/// is exactly the OS share sheet.
class InvoicePreviewShareScreen extends StatefulWidget {
  final Invoice invoice;
  final Book book;
  final PreviewAutoAction autoAction;

  const InvoicePreviewShareScreen({
    super.key,
    required this.invoice,
    required this.book,
    this.autoAction = PreviewAutoAction.none,
  });

  @override
  State<InvoicePreviewShareScreen> createState() => _InvoicePreviewShareScreenState();
}

class _InvoicePreviewShareScreenState extends State<InvoicePreviewShareScreen> {
  final _invoiceRepo = InvoiceRepository();
  late Invoice _invoice;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _generate();
  }

  Future<void> _generate() async {
    final bytes = await InvoicePdfService.generate(book: widget.book, invoice: _invoice);
    if (mounted) setState(() => _pdfBytes = bytes);
    _uploadInBackground(bytes);
    await _runAutoAction(bytes);
  }

  Future<void> _runAutoAction(Uint8List bytes) async {
    switch (widget.autoAction) {
      case PreviewAutoAction.share:
        await Printing.sharePdf(bytes: bytes, filename: '${_invoice.invoiceNumber}.pdf');
        break;
      case PreviewAutoAction.print:
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: _invoice.invoiceNumber);
        break;
      case PreviewAutoAction.none:
        break;
    }
  }

  Future<void> _uploadInBackground(Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('invoices/${widget.book.id}/${_invoice.id}.pdf');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      await _invoiceRepo.updatePdfUrl(_invoice.id, url);
    } catch (_) {
      // Non-fatal - the user can still preview/share the locally generated
      // PDF even if the cloud copy hasn't uploaded yet.
    }
  }

  Future<void> _setStatus(InvoiceStatus status) async {
    switch (status) {
      case InvoiceStatus.paid:
        await _invoiceRepo.markPaid(_invoice);
        setState(() => _invoice = _invoice.copyWith(
              status: status,
              amountReceivedPaise: _invoice.grandTotalPaise,
            ));
        break;
      case InvoiceStatus.unpaid:
        await _invoiceRepo.markUnpaid(_invoice);
        setState(() => _invoice = _invoice.copyWith(status: status));
        break;
      case InvoiceStatus.partial:
        await _invoiceRepo.markPartial(_invoice);
        setState(() => _invoice = _invoice.copyWith(status: status));
        break;
    }
    if (mounted && status == InvoiceStatus.paid) {
      final kind = _invoice.billDirection == BillDirection.purchase ? 'expense' : 'income';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked Paid — matching $kind transaction created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          PopupMenuButton<InvoiceStatus>(
            icon: const Icon(Icons.more_vert),
            onSelected: _setStatus,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: InvoiceStatus.paid, child: Text('Mark Paid')),
              PopupMenuItem(value: InvoiceStatus.partial, child: Text('Mark Partially Paid')),
              PopupMenuItem(value: InvoiceStatus.unpaid, child: Text('Mark Unpaid')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBanner(),
          Expanded(
            child: _pdfBytes == null
                ? const Center(child: CircularProgressIndicator())
                : PdfPreview(
                    build: (format) => _pdfBytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowSharing: true,
                    // Uses share_plus/OS share sheet under the hood -
                    // WhatsApp, email, Drive, print all show up natively.
                    // No custom `actions` here - PdfPreview already adds its
                    // own Print/Share buttons for allowPrinting/allowSharing,
                    // so a second explicit share action just duplicated it.
                    // canDebug defaults to true and adds a raster/vector
                    // debug toggle switch that has no place in a real UI.
                    canDebug: false,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final color = switch (_invoice.status) {
      InvoiceStatus.paid => Colors.green,
      InvoiceStatus.partial => Colors.orange,
      InvoiceStatus.unpaid => Colors.red,
    };
    final label = switch (_invoice.status) {
      InvoiceStatus.paid => 'Paid',
      InvoiceStatus.partial => 'Partially Paid',
      InvoiceStatus.unpaid => 'Unpaid',
    };
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              Text(Money.format(_invoice.grandTotalPaise),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          if (_invoice.amountReceivedPaise > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Received ${Money.format(_invoice.amountReceivedPaise)}'
                '${_invoice.paymentMode != null ? ' via ${_invoice.paymentMode}' : ''}'
                ' · Balance ${Money.format(_invoice.balanceDuePaise)}',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
