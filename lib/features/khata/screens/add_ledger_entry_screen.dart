import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/utils/money.dart';
import '../../books/providers/book_provider.dart';
import '../services/khata_entry_repository.dart';

/// Shared form for both "You Gave" and "You Got", parameterized by [type].
/// When [existingEntry] is set, the form opens pre-filled and Save updates
/// it in place instead of creating a new one (same pattern as
/// OcrReviewFormScreen's existingTransaction editing).
class AddLedgerEntryScreen extends StatefulWidget {
  final Contact contact;
  final KhataEntryType type;
  final KhataEntry? existingEntry;
  const AddLedgerEntryScreen({
    required this.contact,
    required this.type,
    this.existingEntry,
    super.key,
  });

  @override
  State<AddLedgerEntryScreen> createState() => _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends State<AddLedgerEntryScreen> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descriptionCtrl;
  late DateTime _date;
  File? _pickedFile;
  List<KhataAttachment> _keptExistingAttachments = [];
  bool _saving = false;

  bool get _isYouGave => widget.type == KhataEntryType.youGave;
  bool get _isEditing => widget.existingEntry != null;

  bool get _canSave => Money.rupeesStringToPaise(_amountCtrl.text) > 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _amountCtrl = TextEditingController(
      text: existing != null ? Money.paiseToEditableString(existing.amountPaise) : '',
    );
    _descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    _date = existing?.date ?? DateTime.now();
    _keptExistingAttachments = existing?.attachments ?? [];
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: false);
    if (result == null || result.files.single.path == null) return;
    setState(() => _pickedFile = File(result.files.single.path!));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;
    final repo = KhataEntryRepository();

    List<KhataAttachment> attachments = _keptExistingAttachments;
    if (_pickedFile != null) {
      attachments = [
        KhataAttachment(
          url: '',
          uploadedAt: DateTime.now(),
          localPath: _pickedFile!.path,
          fileName: p.basename(_pickedFile!.path),
        ),
      ];
      _uploadAttachmentInBackground(_pickedFile!, book.id);
    }

    await repo.saveEntry(
      id: widget.existingEntry?.id,
      createdAt: widget.existingEntry?.createdAt,
      bookId: book.id,
      contactId: widget.contact.id,
      type: widget.type,
      amountPaise: Money.rupeesStringToPaise(_amountCtrl.text),
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      date: _date,
      attachments: attachments,
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _uploadAttachmentInBackground(File file, String bookId) async {
    try {
      final ext = p.extension(file.path);
      final ref = FirebaseStorage.instance
          .ref('khata_attachments/$bookId/${const Uuid().v4()}$ext');
      await ref.putFile(file);
    } catch (_) {
      // Left for a future sync sweep to retry - never blocks/breaks Save.
    }
  }

  Widget _buildPickedFilePreview() {
    final name = p.basename(_pickedFile!.path);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: Text(name, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _pickedFile = null),
        ),
      ),
    );
  }

  Widget _buildExistingAttachmentPreview() {
    final existing = _keptExistingAttachments.first;
    final name = existing.fileName ?? 'Attached file';

    if (existing.isImageFile) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: existing.localPath != null
                ? Image.file(File(existing.localPath!),
                    height: 140, fit: BoxFit.cover, width: double.infinity)
                : Image.network(existing.url, height: 140, fit: BoxFit.cover, width: double.infinity),
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
                onPressed: () => setState(() => _keptExistingAttachments = []),
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: Text(name, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _keptExistingAttachments = []),
        ),
      ),
    );
  }

  Widget _buildAttachmentField() {
    if (_pickedFile != null) return _buildPickedFilePreview();
    if (_keptExistingAttachments.isNotEmpty) return _buildExistingAttachmentPreview();
    return OutlinedButton.icon(
      icon: const Icon(Icons.attach_file),
      label: const Text('Attach File (optional)'),
      onPressed: _pickFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTitle = _isYouGave ? 'You Gave' : 'You Got';
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit $baseTitle' : baseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.contact.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹) *'),
            onChanged: (_) => setState(() {}),
            autofocus: !_isEditing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          _buildAttachmentField(),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isYouGave ? Colors.red.shade700 : Colors.green.shade700,
            ),
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
