import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/services/attachment_file_service.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/services/category_repository.dart';
import '../../../core/widgets/attachment_card.dart';
import '../../books/providers/book_provider.dart';
import '../../khata/widgets/party_picker_field.dart';
import '../../../l10n/app_localizations.dart';
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
/// - Business Book (Income and Expense): no tax-amount field, no
///   "business use %" field, and no "no receipt available + reason"
///   bypass - the receipt is simply optional on both forms, so there is
///   nothing to waive. The Category dropdown has no built-in
///   categories at all (kept fully separate from the Individual Book's
///   defaults) - only categories the user has created for this book, plus
///   an option to create a new one (of the matching Income/Expense type)
///   on the spot. Every new Business Book is seeded with two Customer
///   contacts ("Daily Counter", "Default Customer") and one Income
///   category ("Daily Counter") - see [BookProvider.createBusinessBook].
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

  /// Individual Book only now - Business Book's party is [_selectedParty],
  /// picked through [PartyPickerField] rather than typed. Kept around (and
  /// still pre-filled from OCR) purely for the Individual Book branch.
  late final TextEditingController _vendorCtrl;
  final _notesCtrl = TextEditingController();

  Category? _category;

  /// Business Book only: the Customer (Income) / Vendor (Expense) this
  /// entry is linked to - same PartyPickerField the Bills form uses, so
  /// picking a party behaves identically in both places. Null until the
  /// user picks one, or once resolved from [AppTransaction.contactId] when
  /// editing.
  Contact? _selectedParty;

  File? _pickedReceiptFile; // chosen via "Choose File" - any format, alternative to camera
  bool _saving = false;

  /// True once the user taps Delete on the OCR-captured photo
  /// (widget.imageFile) - that field is final/passed in, so removal is
  /// tracked here instead of by nulling it out.
  bool _ocrImageRemoved = false;

  final _categoryRepo = CategoryRepository();
  List<Category> _customCategories = [];

  /// Sentinel dropdown item; selecting it opens the "new category" dialog
  /// instead of actually being assignable as a category.
  static final Category _createCategorySentinel =
      Category(id: '__create_new__', name: '+ Create new category', type: TxType.expense);

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
    _vendorCtrl =
        TextEditingController(text: existing?.vendorOrCustomerName ?? widget.ocrResult.vendorName ?? '');
    if (existing != null) {
      _notesCtrl.text = existing.notes ?? '';
      _keptExistingReceiptImages = existing.receiptImages;
      if (existing.contactId != null) {
        final bookId = context.read<BookProvider>().currentBook?.id;
        if (bookId != null) _loadExistingParty(bookId, existing.contactId!);
      }
    }
    _loadCustomCategories();
  }

  bool get _isIncome => widget.type == TxType.income;

  /// Income books to a Customer, Expense to a Vendor - same direction Bills
  /// uses for Sales/Purchase (see CreateBillScreen._partyType).
  ContactType get _partyType => _isIncome ? ContactType.customer : ContactType.vendor;

  /// A method rather than a getter now: the label is translated, so it
  /// needs the resolved localizations rather than a bare string constant.
  String _partyLabel(AppLocalizations l10n) =>
      _isIncome ? l10n.partyCustomer : l10n.partyVendor;

  /// Resolves [AppTransaction.contactId] back to a [Contact] so editing an
  /// existing Business Book entry opens with its party already selected,
  /// the same way CreateBillScreen re-selects a bill's party on edit.
  Future<void> _loadExistingParty(String bookId, String contactId) async {
    final contacts = await ContactRepository().loadContacts(bookId, type: _partyType);
    if (!mounted) return;
    setState(() {
      _selectedParty = contacts.where((c) => c.id == contactId).firstOrNull;
    });
  }

  Future<void> _loadCustomCategories() async {
    final book = context.read<BookProvider>().currentBook;
    if (book == null) return;
    final categories = await _categoryRepo.loadCategories(book.id);
    if (!mounted) return;
    setState(() {
      _customCategories = categories.where((c) => c.type == widget.type).toList();
      final existing = widget.existingTransaction;
      if (existing != null) {
        _category = _categoryOptions(book.isBusiness)
            .where((c) => c.id == existing.categoryId)
            .firstOrNull;
      }
    });
  }

  /// Business Book (Income and Expense) has no built-in categories at all -
  /// kept fully separate from the Individual Book's own defaults - only
  /// categories the user has created for this book are offered.
  List<Category> _categoryOptions(bool isBusiness) => [
        if (!isBusiness) ...Category.defaultsFor(isBusiness).where((c) => c.type == widget.type),
        ..._customCategories,
      ];

  /// Business Book only: lets the user create their own Income/Expense
  /// category (matching this form's [widget.type]) on the spot.
  Future<void> _promptCreateCategory() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        // Two separate keys rather than interpolating "income"/"expense"
        // into one sentence: the noun inflects differently per language,
        // so a single template would read wrong in most of them.
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(_isIncome
              ? l10n.createIncomeCategory
              : l10n.createExpenseCategory),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.categoryNameLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(nameCtrl.text.trim()),
              child: Text(l10n.actionCreate),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;

    final book = context.read<BookProvider>().currentBook;
    if (book == null) return;
    final category = await _categoryRepo.createCategory(
      bookId: book.id,
      name: name,
      type: widget.type,
    );
    if (!mounted) return;
    setState(() {
      _customCategories = [..._customCategories, category];
      _category = category;
    });
  }

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
    });
  }

  bool _canSave(bool isBusiness) {
    if (_amountCtrl.text.trim().isEmpty) return false;
    // Business Book: a party must be picked from Customers/Suppliers (or
    // added/imported on the spot) - there's no free-text fallback, same as
    // a bill can't be saved without a party. Individual Book keeps the
    // plain typed name.
    if (isBusiness) {
      if (_selectedParty == null) return false;
    } else if (_vendorCtrl.text.trim().isEmpty) {
      return false;
    }
    // The receipt attachment is optional in every book and on both the
    // Income and Expense forms, per product decision. Real entries are
    // routinely booked with nothing to attach (bank charges, cash
    // payments, UPI transfers, counter sales), and blocking the save on it
    // only pushed people into attaching something irrelevant.
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;
    final isBusiness = book.isBusiness;
    final repo = TransactionRepository();

    // Upload receipt photo/file in the background; don't block the local
    // save on it (offline-first - SRS Section 9).
    List<ReceiptImage> images = _keptExistingReceiptImages;
    final receiptFile =
        (widget.imageFile != null && !_ocrImageRemoved) ? widget.imageFile : _pickedReceiptFile;
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
      // Business Book: the picked party's name and id, kept in sync so the
      // ledger and the Customers/Suppliers section always agree on who
      // this entry belongs to. Individual Book: the typed name, no contact.
      vendorOrCustomerName:
          isBusiness ? _selectedParty!.name : _vendorCtrl.text.trim(),
      contactId: isBusiness ? _selectedParty!.id : null,
      categoryId: _category?.id,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      businessUsePercent: null,
      receiptImages: images,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedSnack)),
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

  /// Wraps a not-yet-saved local [File] as a [ReceiptImage] so it can reuse
  /// AttachmentFileService's View/Share logic before the transaction exists.
  ReceiptImage _wrapFile(File file) => ReceiptImage(
        imageUrl: '',
        uploadedAt: DateTime.now(),
        localPath: file.path,
        fileName: p.basename(file.path),
      );

  Future<void> _downloadAttachment(ReceiptImage img) async {
    final l10n = AppLocalizations.of(context);
    try {
      final saved = await AttachmentFileService.download(img);
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.downloadedSnack)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.downloadFailed('$e'))));
      }
    }
  }

  /// The receipt attachment widget itself (compact card / choose-file
  /// button) - shared by both Individual and Business layouts, just placed
  /// in a different position in the field order. Deliberately never shows
  /// a full inline preview - "View" opens one on demand instead.
  ///
  /// The empty state says "optional" outright: saving never blocks on a
  /// receipt anywhere (see [_canSave]), so the form should say so rather
  /// than leave the user to discover it.
  Widget _buildReceiptField() {
    if (widget.imageFile != null && !_ocrImageRemoved) {
      final img = _wrapFile(widget.imageFile!);
      return AttachmentCard(
        fileName: AttachmentFileService.fileNameFor(img),
        isImage: img.isImageFile,
        onView: () => AttachmentFileService.view(context, img),
        onShare: () => AttachmentFileService.share(img),
        onDelete: () => setState(() => _ocrImageRemoved = true),
        onDownload: () => _downloadAttachment(img),
      );
    }
    if (_pickedReceiptFile != null) {
      final img = _wrapFile(_pickedReceiptFile!);
      return AttachmentCard(
        fileName: AttachmentFileService.fileNameFor(img),
        isImage: img.isImageFile,
        onView: () => AttachmentFileService.view(context, img),
        onShare: () => AttachmentFileService.share(img),
        onDelete: () => setState(() => _pickedReceiptFile = null),
        onDownload: () => _downloadAttachment(img),
      );
    }
    if (_keptExistingReceiptImages.isNotEmpty) {
      final existing = _keptExistingReceiptImages.first;
      return AttachmentCard(
        fileName: AttachmentFileService.fileNameFor(existing),
        isImage: existing.isImageFile,
        onView: () => AttachmentFileService.view(context, existing),
        onShare: () => AttachmentFileService.share(existing),
        onDelete: () => setState(() => _keptExistingReceiptImages = []),
        onDownload: () => _downloadAttachment(existing),
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.attach_file),
      label: Text(AppLocalizations.of(context).chooseReceiptFile),
      onPressed: _pickReceiptFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == TxType.income;
    final l10n = AppLocalizations.of(context);
    final book = context.watch<BookProvider>().currentBook;
    final isBusiness = book?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (isIncome ? l10n.editIncome : l10n.editExpense)
            : (isIncome ? l10n.reviewIncome : l10n.reviewExpense)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Business Book: receipt goes at the top, same as the original
          // SRS 8 flow (receipt is the first thing you deal with) - though
          // it no longer blocks saving, on either form (see _canSave).
          if (isBusiness) ...[
            _buildReceiptField(),
            if (!widget.ocrResult.success && widget.imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.ocrFailedBelow,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.date),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          // Business Book: the party is picked from Customers/Suppliers
          // (or added/imported on the spot) - same PartyPickerField the
          // Bills form uses, rather than a freely-typed name. Individual
          // Book keeps the plain text field; it has no Customers/Suppliers
          // section for a picker to draw from.
          if (isBusiness) ...[
            Text(_partyLabel(l10n), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            PartyPickerField(
              bookId: book!.id,
              type: _partyType,
              label: _partyLabel(l10n),
              selected: _selectedParty,
              onChanged: (c) => setState(() => _selectedParty = c),
            ),
            if (_selectedParty == null &&
                (widget.ocrResult.vendorName?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isIncome
                      ? l10n.receiptShowsCustomerHint(widget.ocrResult.vendorName!)
                      : l10n.receiptShowsVendorHint(widget.ocrResult.vendorName!),
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ] else
            TextField(
              controller: _vendorCtrl,
              decoration: InputDecoration(
                  labelText: isIncome
                      ? l10n.payerCustomerNameRequired
                      : l10n.vendorNameRequired),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: isBusiness ? l10n.amountLabel : l10n.amountLabelRequired),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Category>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l10n.category),
            items: [
              ..._categoryOptions(isBusiness)
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(systemCategoryName(l10n, c)))),
              if (isBusiness)
                DropdownMenuItem(
                  value: _createCategorySentinel,
                  child: Text(l10n.createNewCategoryOption),
                ),
            ],
            onChanged: (v) {
              if (v == _createCategorySentinel) {
                _promptCreateCategory();
                return;
              }
              setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
                labelText: isBusiness ? l10n.notesOptional : l10n.notesLabel),
            maxLines: 2,
          ),
          if (!isBusiness) ...[
            // Individual Book: receipt is just another optional field,
            // placed here in the normal flow instead of at the top.
            const SizedBox(height: 12),
            _buildReceiptField(),
            if (!widget.ocrResult.success && widget.imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.ocrFailedAbove,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_canSave(isBusiness) && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}