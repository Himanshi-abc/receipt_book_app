import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/services/transaction_repository.dart';
import '../../books/providers/book_provider.dart';
import '../services/ocr_service.dart';

/// SRS 4.2 steps 5-7 + the hard rule: "If OCR fails completely or the user
/// has no internet, the form should still open blank and let them type
/// everything manually - saving must never be blocked by OCR."
/// This single screen serves both the Income and Expense variants
/// (Section 6, screen 5) - the only difference is `type`.
///
/// Per product decision, this form now behaves differently depending on
/// which kind of Book is currently open:
///
/// - Individual Book: simplified per-transaction entry. Only Amount and
///   Vendor/Payer name are mandatory. No tax-amount field. No "no receipt +
///   reason" flow - the receipt attachment is just another optional field,
///   placed in the normal field order rather than as a special step.
/// - Business Book: unchanged from the original SRS 8 behavior - tax
///   amount field present, and a receipt is required unless the user
///   explicitly checks "no receipt available" and gives a reason.
class OcrReviewFormScreen extends StatefulWidget {
  final TxType type;
  final File? imageFile;
  final OcrResult ocrResult;

  /// When set, the form opens pre-filled with this transaction's data and
  /// saving updates it in place instead of creating a new one.
  final AppTransaction? existingTransaction;

  const OcrReviewFormScreen({
    super.key,
    required this.type,
    required this.imageFile,
    required this.ocrResult,
    this.existingTransaction,
  });

  @override
  State<OcrReviewFormScreen> createState() => _OcrReviewFormScreenState();
}

class _OcrReviewFormScreenState extends State<OcrReviewFormScreen> {
  late DateTime _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _vendorCtrl;
  final _notesCtrl = TextEditingController();

  Category? _category;
  int _businessUsePercent = 100;
  File? _pickedReceiptFile; // chosen via "Choose File" - any format, alternative to camera
  bool _noReceipt = false;
  final _noReceiptReasonCtrl = TextEditingController();
  bool _saving = false;

  /// Receipts already attached to the transaction being edited. Carried
  /// forward on save unless the user picks a replacement file.
  List<ReceiptImage> _keptExistingReceiptImages = [];

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    _date = existing?.date ?? widget.ocrResult.date ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: existing != null
          ? Money.paiseToEditableString(existing.amountPaise)
          : widget.ocrResult.amountPaise != null
              ? Money.paiseToEditableString(widget.ocrResult.amountPaise!)
              : '',
    );
    _taxCtrl = TextEditingController(
      text: existing != null
          ? Money.paiseToEditableString(existing.taxAmountPaise)
          : widget.ocrResult.taxAmountPaise != null
              ? Money.paiseToEditableString(widget.ocrResult.taxAmountPaise!)
              : '',
    );
    _vendorCtrl =
        TextEditingController(text: existing?.vendorOrCustomerName ?? widget.ocrResult.vendorName ?? '');
    if (existing != null) {
      _notesCtrl.text = existing.notes ?? '';
      _businessUsePercent = existing.businessUsePercent ?? 100;
      _noReceipt = existing.noReceiptAvailable;
      _noReceiptReasonCtrl.text = existing.noReceiptReason ?? '';
      _keptExistingReceiptImages = existing.receiptImages;
      final isBusiness = context.read<BookProvider>().currentBook?.isBusiness == true;
      _category = _categoryOptions(isBusiness)
          .where((c) => c.id == existing.categoryId)
          .firstOrNull;
    }
  }

  List<Category> _categoryOptions(bool isBusiness) => Category.defaultsFor(isBusiness)
      .where((c) => c.type == widget.type)
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceiptFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pickedReceiptFile = File(result.files.single.path!);
      _noReceipt = false; // mutually exclusive with "no receipt available" (Business Book)
    });
  }

  bool get _hasAnyReceipt =>
      widget.imageFile != null ||
      _pickedReceiptFile != null ||
      _keptExistingReceiptImages.isNotEmpty;

  bool _canSave(bool isBusiness) {
    if (_amountCtrl.text.trim().isEmpty) return false;
    if (_vendorCtrl.text.trim().isEmpty) return false;
    if (!isBusiness) return true; // Individual Book: nothing else required
    // Business Book keeps the original SRS 8 rule: receipt required unless
    // "no receipt" is checked with a reason.
    if (!_noReceipt && !_hasAnyReceipt) return false;
    if (_noReceipt && _noReceiptReasonCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save(bool isBusiness) async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;
    final repo = TransactionRepository();

    // Upload receipt photo/file in the background; don't block the local
    // save on it (offline-first - SRS Section 9).
    List<ReceiptImage> images = _keptExistingReceiptImages;
    final receiptFile = widget.imageFile ?? _pickedReceiptFile;
    if (receiptFile != null) {
      images = [
        ReceiptImage(
          imageUrl: '', // filled in once uploaded; localPath used until then
          uploadedAt: DateTime.now(),
          localPath: receiptFile.path,
          fileName: p.basename(receiptFile.path),
        ),
      ];
      _uploadReceiptInBackground(receiptFile, book.id);
    }

    await repo.saveTransaction(
      id: widget.existingTransaction?.id,
      createdAt: widget.existingTransaction?.createdAt,
      bookId: book.id,
      type: widget.type,
      date: _date,
      amountPaise: Money.rupeesStringToPaise(_amountCtrl.text),
      taxAmountPaise: isBusiness ? Money.rupeesStringToPaise(_taxCtrl.text) : 0,
      vendorOrCustomerName: _vendorCtrl.text.trim(),
      categoryId: _category?.id,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      businessUsePercent: isBusiness ? _businessUsePercent : null,
      receiptImages: images,
      noReceiptAvailable: isBusiness ? _noReceipt : false,
      noReceiptReason: (isBusiness && _noReceipt) ? _noReceiptReasonCtrl.text.trim() : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      if (_isEditing) {
        Navigator.of(context).pop(); // back to the transaction detail screen
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  Future<void> _uploadReceiptInBackground(File file, String bookId) async {
    try {
      final ext = p.extension(file.path); // preserves .pdf, .png, .docx, etc.
      final ref = FirebaseStorage.instance
          .ref('receipts/$bookId/${const Uuid().v4()}$ext');
      await ref.putFile(file);
      // In a full implementation: update the transaction's receiptImages[0].imageUrl
      // with the download URL once upload completes, and clear localPath.
    } catch (_) {
      // Left for the background sync sweep to retry - never surfaced as an
      // error to the user; the local photo path still works for viewing.
    }
  }

  Widget _buildPickedFilePreview() {
    final path = _pickedReceiptFile!.path;
    final name = p.basename(path);
    final isImage = ReceiptImage(imageUrl: '', uploadedAt: DateTime.now(), fileName: name)
        .isImageFile;

    if (isImage) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_pickedReceiptFile!, height: 160, fit: BoxFit.cover, width: double.infinity),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: () => setState(() => _pickedReceiptFile = null),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, size: 32),
        title: Text(name, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _pickedReceiptFile = null),
        ),
      ),
    );
  }

  Widget _buildExistingReceiptPreview() {
    final existing = _keptExistingReceiptImages.first;
    final name = existing.fileName ?? 'Receipt file';

    if (existing.isImageFile) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: existing.localPath != null
                ? Image.file(File(existing.localPath!),
                    height: 160, fit: BoxFit.cover, width: double.infinity)
                : Image.network(existing.imageUrl,
                    height: 160, fit: BoxFit.cover, width: double.infinity),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: () => setState(() => _keptExistingReceiptImages = []),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, size: 32),
        title: Text(name, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _keptExistingReceiptImages = []),
        ),
      ),
    );
  }

  /// The receipt attachment widget itself (image preview / picked file tile
  /// / choose-file button) - shared by both Individual and Business layouts,
  /// just placed in a different position in the field order.
  Widget _buildReceiptField() {
    if (widget.imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(widget.imageFile!, height: 160, fit: BoxFit.cover),
      );
    }
    if (_pickedReceiptFile != null) return _buildPickedFilePreview();
    if (_keptExistingReceiptImages.isNotEmpty) return _buildExistingReceiptPreview();
    return OutlinedButton.icon(
      icon: const Icon(Icons.attach_file),
      label: const Text('Choose Receipt File (any format)'),
      onPressed: _pickReceiptFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == TxType.income;
    final book = context.watch<BookProvider>().currentBook;
    final isBusiness = book?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (isIncome ? 'Edit Income' : 'Edit Expense')
            : (isIncome ? 'Review Income' : 'Review Expense')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Book: receipt goes at the top, same as the original
          // SRS 8 flow (receipt is the first thing you deal with).
          if (isBusiness) ...[
            _buildReceiptField(),
            if (!widget.ocrResult.success && widget.imageFile != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Couldn't auto-read this receipt — please fill in the details below.",
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          TextField(
            controller: _vendorCtrl,
            decoration: InputDecoration(
                labelText: isIncome
                    ? (isBusiness ? 'Payer / Customer name' : 'Payer / Customer name *')
                    : (isBusiness ? 'Vendor name' : 'Vendor name *')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: isBusiness ? 'Amount (₹)' : 'Amount (₹) *'),
            onChanged: (_) => setState(() {}),
          ),
          if (isBusiness) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _taxCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tax amount (₹, if visible)'),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<Category>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categoryOptions(isBusiness)
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: isBusiness ? 'Notes (optional)' : 'Notes'),
            maxLines: 2,
          ),
          if (isBusiness && widget.type == TxType.expense) ...[
            const SizedBox(height: 12),
            Text('Business use: $_businessUsePercent%'),
            Slider(
              value: _businessUsePercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_businessUsePercent%',
              onChanged: (v) => setState(() => _businessUsePercent = v.round()),
            ),
          ],
          if (isBusiness) ...[
            const Divider(height: 32),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _noReceipt,
              title: const Text('No receipt available'),
              onChanged: (v) => setState(() {
                _noReceipt = v ?? false;
                if (_noReceipt) _pickedReceiptFile = null;
              }),
            ),
            if (_noReceipt)
              TextField(
                controller: _noReceiptReasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason (required)'),
              ),
          ] else ...[
            // Individual Book: receipt is just another optional field,
            // placed here in the normal flow instead of at the top.
            const SizedBox(height: 12),
            _buildReceiptField(),
            if (!widget.ocrResult.success && widget.imageFile != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Couldn't auto-read this receipt — please fill in the details above.",
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_canSave(isBusiness) && !_saving) ? () => _save(isBusiness) : null,
            child: _saving
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}