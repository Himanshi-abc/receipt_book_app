import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
class OcrReviewFormScreen extends StatefulWidget {
  final TxType type;
  final File? imageFile;
  final OcrResult ocrResult;

  const OcrReviewFormScreen({
    super.key,
    required this.type,
    required this.imageFile,
    required this.ocrResult,
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
  bool _noReceipt = false;
  final _noReceiptReasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.ocrResult.date ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: widget.ocrResult.amountPaise != null
          ? Money.paiseToEditableString(widget.ocrResult.amountPaise!)
          : '',
    );
    _taxCtrl = TextEditingController(
      text: widget.ocrResult.taxAmountPaise != null
          ? Money.paiseToEditableString(widget.ocrResult.taxAmountPaise!)
          : '',
    );
    _vendorCtrl = TextEditingController(text: widget.ocrResult.vendorName ?? '');
  }

  List<Category> get _categoryOptions => Category.systemDefaults()
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

  bool get _canSave {
    if (_amountCtrl.text.trim().isEmpty) return false;
    if (_vendorCtrl.text.trim().isEmpty) return false;
    if (!_noReceipt && widget.imageFile == null) return false;
    if (_noReceipt && _noReceiptReasonCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;
    final repo = TransactionRepository();

    // Upload receipt photo in the background; don't block the local save
    // on it (offline-first - SRS Section 9).
    List<ReceiptImage> images = [];
    if (widget.imageFile != null) {
      images = [
        ReceiptImage(
          imageUrl: '', // filled in once uploaded; localPath used until then
          uploadedAt: DateTime.now(),
          localPath: widget.imageFile!.path,
        ),
      ];
      _uploadReceiptInBackground(widget.imageFile!, book.id);
    }

    await repo.saveTransaction(
      bookId: book.id,
      type: widget.type,
      date: _date,
      amountPaise: Money.rupeesStringToPaise(_amountCtrl.text),
      taxAmountPaise: Money.rupeesStringToPaise(_taxCtrl.text),
      vendorOrCustomerName: _vendorCtrl.text.trim(),
      categoryId: _category?.id,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      businessUsePercent: book.isBusiness ? _businessUsePercent : null,
      receiptImages: images,
      noReceiptAvailable: _noReceipt,
      noReceiptReason: _noReceipt ? _noReceiptReasonCtrl.text.trim() : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _uploadReceiptInBackground(File file, String bookId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref('receipts/$bookId/${const Uuid().v4()}.jpg');
      await ref.putFile(file);
      // In a full implementation: update the transaction's receiptImages[0].imageUrl
      // with the download URL once upload completes, and clear localPath.
    } catch (_) {
      // Left for the background sync sweep to retry - never surfaced as an
      // error to the user; the local photo path still works for viewing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == TxType.income;
    return Scaffold(
      appBar: AppBar(title: Text(isIncome ? 'Review Income' : 'Review Expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(widget.imageFile!, height: 160, fit: BoxFit.cover),
            ),
          if (!widget.ocrResult.success && widget.imageFile != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Couldn't auto-read this receipt — please fill in the details below.",
                style: TextStyle(color: Colors.orange),
              ),
            ),
          const SizedBox(height: 16),
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
                labelText: isIncome ? 'Payer / Customer name' : 'Vendor name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taxCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tax amount (₹, if visible)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Category>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categoryOptions
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          if (context.watch<BookProvider>().currentBook?.isBusiness == true &&
              widget.type == TxType.expense) ...[
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
          const Divider(height: 32),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _noReceipt,
            title: const Text('No receipt available'),
            onChanged: (v) => setState(() => _noReceipt = v ?? false),
          ),
          if (_noReceipt)
            TextField(
              controller: _noReceiptReasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_canSave && !_saving) ? _save : null,
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
