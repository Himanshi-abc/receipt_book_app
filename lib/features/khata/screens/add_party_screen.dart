import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:provider/provider.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../l10n/app_localizations.dart';
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
    final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    final granted = status == fc.PermissionStatus.granted || status == fc.PermissionStatus.limited;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).contactsDeniedAddManually),
          ),
        );
      }
      return;
    }

    final deviceContacts = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
    if (!mounted) return;

    final picked = await showModalBottomSheet<fc.Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DeviceContactPickerSheet(contacts: deviceContacts),
    );
    if (picked == null) return;

    setState(() {
      _nameCtrl.text = picked.displayName ?? '';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedSnack)),
      );
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCustomer = widget.defaultType == ContactType.customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (isCustomer ? l10n.editCustomer : l10n.editSupplier)
            : (isCustomer ? l10n.addCustomer : l10n.addSupplier)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.contacts_outlined),
            label: Text(l10n.addFromContacts),
            onPressed: _pickFromContacts,
          ),
          const SizedBox(height: 8),
          Text(l10n.orFillInDetailsBelow,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: l10n.partyNameRequired),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.mobileNumberRequired),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ContactType>(
            segments: [
              ButtonSegment(
                  value: ContactType.customer, label: Text(l10n.partyCustomer)),
              ButtonSegment(
                  value: ContactType.vendor, label: Text(l10n.partySupplier)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gstinCtrl,
            decoration: InputDecoration(labelText: l10n.gstinOptional),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(labelText: l10n.addressOptional),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_canSave && !_saving) ? _save : null,
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
          : widget.contacts
              .where((c) => (c.displayName ?? '').toLowerCase().contains(q))
              .toList();
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
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchContacts,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _filter,
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context).noContactsFound))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          return ListTile(
                            title: Text(c.displayName ?? ''),
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
