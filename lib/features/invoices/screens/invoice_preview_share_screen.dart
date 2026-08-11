import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../bills/screens/create_bill_screen.dart' show paymentModeLabel;
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
      final l10n = AppLocalizations.of(context);
      // Two whole sentences rather than one with an "income"/"expense"
      // placeholder - the noun takes different case marking in several of
      // the supported languages.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_invoice.billDirection == BillDirection.purchase
              ? l10n.markedPaidExpenseCreated
              : l10n.markedPaidIncomeCreated),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          PopupMenuButton<InvoiceStatus>(
            icon: const Icon(Icons.more_vert),
            onSelected: _setStatus,
            itemBuilder: (ctx) => [
              PopupMenuItem(value: InvoiceStatus.paid, child: Text(l10n.markPaid)),
              PopupMenuItem(
                  value: InvoiceStatus.partial, child: Text(l10n.markPartiallyPaid)),
              PopupMenuItem(value: InvoiceStatus.unpaid, child: Text(l10n.markUnpaid)),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final (tone, label, icon) = switch (_invoice.status) {
      InvoiceStatus.paid => (AppTone.positive, l10n.paid, Icons.check_circle_outline),
      InvoiceStatus.partial =>
        (AppTone.warning, l10n.statusPartPaid, Icons.schedule),
      InvoiceStatus.unpaid =>
        (AppTone.negative, l10n.statusUnpaid, Icons.error_outline),
    };
    final toneColors = context.tones.byTone(tone);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: toneColors.bg,
        border: Border(bottom: BorderSide(color: toneColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon + label, so status survives greyscale printing and
              // colour-vision deficiency (WCAG 1.4.1).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: toneColors.fg),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(color: toneColors.fg),
                  ),
                ],
              ),
              MoneyText(
                _invoice.grandTotalPaise,
                tone: tone,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (_invoice.amountReceivedPaise > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${_invoice.paymentMode == null ? l10n.receivedAmount(Money.format(_invoice.amountReceivedPaise)) : l10n.receivedAmountViaMode(Money.format(_invoice.amountReceivedPaise), paymentModeLabel(l10n, _invoice.paymentMode!))}'
                '  ·  '
                '${l10n.balanceAmount(Money.format(_invoice.balanceDuePaise))}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: toneColors.fg)
                    .tabular,
              ),
            ),
        ],
      ),
    );
  }
}
