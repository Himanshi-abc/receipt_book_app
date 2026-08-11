import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/attachment_file_service.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/attachment_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/providers/book_provider.dart';
import '../../scan/screens/ocr_review_form_screen.dart';
import '../../scan/services/ocr_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String bookId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    required this.bookId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _repo = TransactionRepository();
  AppTransaction? _tx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.loadTransactions(widget.bookId);
    setState(() {
      _tx = all.where((t) => t.id == widget.transactionId).firstOrNull;
    });
  }

  Future<void> _edit() async {
    if (_tx == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewFormScreen(
          type: _tx!.type,
          imageFile: null,
          ocrResult: OcrResult.failed(),
          existingTransaction: _tx,
        ),
      ),
    );
    _load();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTransactionTitle),
        content: Text(l10n.deletePartyMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed == true && _tx != null) {
      await _repo.softDelete(_tx!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _shareAttachment(ReceiptImage img) async {
    try {
      await AttachmentFileService.share(img);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(
                AppLocalizations.of(context).couldNotShareFile('$e'))));
      }
    }
  }

  Future<void> _downloadAttachment(ReceiptImage img) async {
    try {
      final saved = await AttachmentFileService.download(img);
      // false means the user cancelled the save dialog - not an error, so
      // no snackbar in that case.
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
                content: Text(AppLocalizations.of(context).downloadedSnack)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(
                AppLocalizations.of(context).downloadFailed('$e'))));
      }
    }
  }

  Future<void> _deleteAttachment(ReceiptImage img) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeAttachmentTitle),
        content: Text(l10n.cannotBeUndone),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.actionRemove)),
        ],
      ),
    );
    if (confirmed != true || _tx == null) return;

    final tx = _tx!;
    final updatedImages = tx.receiptImages.where((i) => i != img).toList();
    await AttachmentFileService.deleteUnderlyingFile(img);
    await _repo.saveTransaction(
      id: tx.id,
      createdAt: tx.createdAt,
      bookId: tx.bookId,
      type: tx.type,
      date: tx.date,
      amountPaise: tx.amountPaise,
      taxAmountPaise: tx.taxAmountPaise,
      vendorOrCustomerName: tx.vendorOrCustomerName,
      contactId: tx.contactId,
      categoryId: tx.categoryId,
      notes: tx.notes,
      businessUsePercent: tx.businessUsePercent,
      taxHead: tx.taxHead,
      receiptImages: updatedImages,
      noReceiptAvailable: tx.noReceiptAvailable,
      noReceiptReason: tx.noReceiptReason,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).attachmentRemoved)));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final writable = context.watch<BookProvider>().currentBookIsWritable;
    final book = context.watch<BookProvider>().currentBook;
    final isBusiness = book?.isBusiness == true;
    if (_tx == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tx = _tx!;
    final isIncome = tx.type == TxType.income;

    // Compact "one row" cards only - never a full inline preview. View
    // (images: full-screen; other files: open externally), Share, Delete,
    // and Download are available for every attachment, same for both book
    // types.
    final receiptSection = tx.receiptImages.isNotEmpty
        ? tx.receiptImages
            .map((img) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AttachmentCard(
                    fileName: AttachmentFileService.fileNameFor(img),
                    isImage: img.isImageFile,
                    onView: () => AttachmentFileService.view(context, img),
                    onShare: () => _shareAttachment(img),
                    onDelete: () => _deleteAttachment(img),
                    onDownload: () => _downloadAttachment(img),
                  ),
                ))
            .toList()
        : <Widget>[
            isBusiness
                ? Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l10n.noReceiptOnFileReason(
                          tx.noReceiptReason ?? '-')),
                    ),
                  )
                : Text(l10n.noReceiptAttached,
                    style: TextStyle(color: Colors.grey.shade600)),
          ];

    final detailRows = <Widget>[
      DetailRow(label: l10n.fieldAmount, value: Money.format(tx.amountPaise)),
      if (isBusiness)
        DetailRow(label: l10n.fieldTax, value: Money.format(tx.taxAmountPaise)),
      DetailRow(
          label: isIncome ? l10n.payerCustomer : l10n.partyVendor,
          value: tx.vendorOrCustomerName),
      DetailRow(
          label: l10n.date,
          value: '${tx.date.day}/${tx.date.month}/${tx.date.year}'),
      DetailRow(label: l10n.financialYear, value: tx.financialYear),
      if (tx.notes != null) DetailRow(label: l10n.notesLabel, value: tx.notes!),
      if (tx.businessUsePercent != null)
        DetailRow(
            label: l10n.businessUse, value: '${tx.businessUsePercent}%'),
      if (tx.pendingSync)
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(l10n.waitingToSync,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? l10n.typeIncome : l10n.typeExpense),
        actions: [
          if (writable)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          if (writable)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        // Business Book: receipt first (original SRS 8 ordering).
        // Individual Book: text details first, receipt shown below them.
        children: isBusiness
            ? [...receiptSection, ...detailRows]
            : [
                ...detailRows,
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(l10n.receipt,
                    style: TextStyle(
                        color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...receiptSection,
              ],
      ),
    );
  }

}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
