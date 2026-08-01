import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/invoice_template.dart';
import '../../books/providers/book_provider.dart';
import '../services/dummy_invoice_data.dart';
import '../services/invoice_pdf_service.dart';

/// Full, real PDF render of an InvoiceTemplateStyle using entirely dummy
/// data (see DummyInvoiceData) - this runs the exact same
/// InvoicePdfService pipeline a real invoice would, so what's on screen
/// here is exactly how this book's invoices will actually look once
/// applied, not an approximation.
///
/// The page is rasterised to an image and shown in an [InteractiveViewer],
/// the same way an attachment opens, rather than through the `printing`
/// package's PdfPreview. PdfPreview ships a toolbar of print / share /
/// page-format / orientation controls, none of which belong on a screen
/// whose only question is "do you want this design?" - printing a sample
/// invoice full of placeholder data is never something a user meant to do.
class InvoiceTemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplateStyle style;
  const InvoiceTemplatePreviewScreen({super.key, required this.style});

  @override
  State<InvoiceTemplatePreviewScreen> createState() =>
      _InvoiceTemplatePreviewScreenState();
}

class _InvoiceTemplatePreviewScreenState
    extends State<InvoiceTemplatePreviewScreen> {
  Uint8List? _pageImage;
  bool _applying = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      final pdfBytes = await InvoicePdfService.generate(
        book: DummyInvoiceData.book(),
        invoice: DummyInvoiceData.invoice(),
        templateId: widget.style.id,
      );

      // 150 dpi puts an A4 page at roughly 1240x1754 - sharp enough to read
      // the line items when zoomed in, without the memory cost of print
      // resolution for what is only ever shown on screen.
      final page = await Printing.raster(pdfBytes, dpi: 150).first;
      final png = await page.toPng();
      if (mounted) setState(() => _pageImage = png);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _useTemplate() async {
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) return;
    setState(() => _applying = true);
    await bookProvider.updateBook(book.id, {'invoiceTemplateId': widget.style.id});
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Scaffold(
      appBar: AppBar(title: Text(widget.style.name)),
      // A neutral backdrop rather than the page colour, so the edges of the
      // sheet are visible and it reads as a document rather than as the
      // screen's own background.
      backgroundColor: tones.canvas,
      body: Column(
        children: [
          Expanded(child: _buildPage(theme, tones)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.sm,
                AppSpacing.pageGutter,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sample invoice with placeholder data.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: tones.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _applying ? null : _useTemplate,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _applying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Use This Template'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(ThemeData theme, AppSemanticColors tones) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 40, color: tones.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Couldn't render this sample.",
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You can still apply the template - your real invoices are '
                'generated separately.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    if (_pageImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return InteractiveViewer(
      // Room to zoom in on the tax columns, which is the detail people
      // actually want to inspect before committing to a design.
      maxScale: 5,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: tones.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.memory(_pageImage!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
