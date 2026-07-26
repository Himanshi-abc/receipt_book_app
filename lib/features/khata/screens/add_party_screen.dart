import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:provider/provider.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../books/providers/book_provider.dart';

/// Add a new Customer or Supplier, either picked from the device's
/// contacts (name/phone pre-filled, still lands here to confirm/complete)
/// or filled in manually from scratch. When [existingContact] is set, the
/// form opens pre-filled and Save updates it in place (edit mode).
class AddPartyScreen extends StatefulWidget {
  final ContactType defaultType;
  final Contact? existingContact;
  const AddPartyScreen({required this.defaultType, this.existingContact, super.key});

  @override
  State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _addressCtrl;
  late ContactType _type;
  bool _saving = false;

  bool get _isEditing => widget.existingContact != null;

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContact;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    _gstinCtrl = TextEditingController(text: existing?.gstin ?? '');
    _addressCtrl = TextEditingController(text: existing?.address ?? '');
    _type = existing?.type ?? widget.defaultType;
  }

  Future<void> _pickFromContacts() async {
    final granted = await fc.FlutterContacts.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts access was denied. You can still add this party manually.'),
          ),
        );
      }
      return;
    }

    final deviceContacts = await fc.FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;

    final picked = await showModalBottomSheet<fc.Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DeviceContactPickerSheet(contacts: deviceContacts),
    );
    if (picked == null) return;

    setState(() {
      _nameCtrl.text = picked.displayName;
      _phoneCtrl.text = picked.phones.isNotEmpty ? picked.phones.first.number : '';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;

    final saved = await ContactRepository().saveContact(
      id: widget.existingContact?.id,
      bookId: book.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      type: _type,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (widget.defaultType == ContactType.customer ? 'Edit Customer' : 'Edit Supplier')
            : (widget.defaultType == ContactType.customer ? 'Add Customer' : 'Add Supplier')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.contacts_outlined),
            label: const Text('Add from Contacts'),
            onPressed: _pickFromContacts,
          ),
          const SizedBox(height: 8),
          Text('or fill in the details below', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Party Name *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile Number *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ContactType>(
            segments: const [
              ButtonSegment(value: ContactType.customer, label: Text('Customer')),
              ButtonSegment(value: ContactType.vendor, label: Text('Supplier')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gstinCtrl,
            decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
            maxLines: 2,
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

class _DeviceContactPickerSheet extends StatefulWidget {
  final List<fc.Contact> contacts;
  const _DeviceContactPickerSheet({required this.contacts});

  @override
  State<_DeviceContactPickerSheet> createState() => _DeviceContactPickerSheetState();
}

class _DeviceContactPickerSheetState extends State<_DeviceContactPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<fc.Contact> _filtered = widget.contacts;

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts.where((c) => c.displayName.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search contacts',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _filter,
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No contacts found.'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          return ListTile(
                            title: Text(c.displayName),
                            subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : ''),
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
