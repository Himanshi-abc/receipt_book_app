import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice_template.dart';
import '../../books/providers/book_provider.dart';
import '../services/dummy_invoice_data.dart';
import '../services/invoice_pdf_service.dart';

/// Full, real PDF render of an InvoiceTemplateStyle using entirely dummy
/// data (see DummyInvoiceData) - this runs the exact same
/// InvoicePdfService pipeline a real invoice would, so what's on screen
/// here is exactly how this book's invoices will actually look once
/// applied, not an approximation.
class InvoiceTemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplateStyle style;
  const InvoiceTemplatePreviewScreen({super.key, required this.style});

  @override
  State<InvoiceTemplatePreviewScreen> createState() => _InvoiceTemplatePreviewScreenState();
}

class _InvoiceTemplatePreviewScreenState extends State<InvoiceTemplatePreviewScreen> {
  Uint8List? _bytes;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final bytes = await InvoicePdfService.generate(
      book: DummyInvoiceData.book(),
      invoice: DummyInvoiceData.invoice(),
      templateId: widget.style.id,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  Future<void> _useTemplate() async {
    final book = context.read<BookProvider>().currentBook;
    if (book == null) return;
    setState(() => _applying = true);
    await context.read<BookProvider>().updateBook(book.id, {'invoiceTemplateId': widget.style.id});
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.style.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Sample invoice with placeholder data - this is exactly how your real '
              'invoices will look with the "${widget.style.name}" template.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: _bytes == null
                ? const Center(child: CircularProgressIndicator())
                : PdfPreview(
                    build: (format) => _bytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowSharing: false,
                    actions: const [],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _applying ? null : _useTemplate,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _applying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Use This Template'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
