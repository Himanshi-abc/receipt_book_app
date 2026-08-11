import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../../core/models/contact_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../screens/add_party_screen.dart';

/// The "pick a Customer or Supplier" control: Select existing / Add new /
/// Import from device Contacts, collapsing into a single card once a party
/// is chosen.
///
/// Pulled out of CreateBillScreen (Bills) into one shared widget so this
/// exact behaviour can be reused verbatim wherever else a party needs to be
/// picked - see OcrReviewFormScreen's Business Book Income/Expense entry -
/// rather than growing a second, subtly-different copy that drifts from
/// the first over time.
class PartyPickerField extends StatelessWidget {
  final String bookId;
  final ContactType type;

  /// "Customer" or "Supplier" - drives both the button labels and the
  /// sheet/screen titles opened from here.
  final String label;

  final Contact? selected;
  final ValueChanged<Contact> onChanged;

  const PartyPickerField({
    super.key,
    required this.bookId,
    required this.type,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _selectExisting(BuildContext context) async {
    final contacts = await ContactRepository().loadContacts(bookId, type: type);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExistingPartySheet(contacts: contacts, partyType: type),
    );
    if (picked != null) onChanged(picked);
  }

  Future<void> _addManually(BuildContext context) async {
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(builder: (_) => AddPartyScreen(defaultType: type)),
    );
    if (result != null) onChanged(result);
  }

  Future<void> _importFromContacts(BuildContext context) async {
    final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
    final granted = status == fc.PermissionStatus.granted || status == fc.PermissionStatus.limited;
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).contactsAccessDenied)),
        );
      }
      return;
    }
    final deviceContacts = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<fc.Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DeviceContactPickerSheet(contacts: deviceContacts),
    );
    if (picked == null) return;

    final saved = await ContactRepository().saveContact(
      bookId: bookId,
      name: picked.displayName ?? '',
      phone: picked.phones.isNotEmpty ? picked.phones.first.number : null,
      type: type,
    );
    onChanged(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCustomer = type == ContactType.customer;
    final party = selected;
    if (party != null) {
      return Card(
        child: ListTile(
          title: Text(party.name),
          subtitle: Text(party.phone ?? ''),
          trailing: TextButton(
            onPressed: () => _selectExisting(context),
            child: Text(l10n.actionChange),
          ),
        ),
      );
    }

    // Whole phrases per party type rather than "Select $label": building a
    // verb phrase by concatenating a translated noun only works in English.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: Text(isCustomer ? l10n.selectCustomer : l10n.selectSupplier),
          onPressed: () => _selectExisting(context),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: Text(isCustomer ? l10n.addCustomer : l10n.addSupplier),
          onPressed: () => _addManually(context),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.contacts_outlined),
          label: Text(l10n.importFromContacts),
          onPressed: () => _importFromContacts(context),
        ),
      ],
    );
  }
}

class _ExistingPartySheet extends StatefulWidget {
  final List<Contact> contacts;
  /// The party type, not a pre-rendered label: the sheet needs to pick
  /// whole translated phrases ("Search customers by name"), which can't be
  /// assembled from a noun the caller already formatted.
  final ContactType partyType;
  const _ExistingPartySheet({required this.contacts, required this.partyType});

  @override
  State<_ExistingPartySheet> createState() => _ExistingPartySheetState();
}

class _ExistingPartySheetState extends State<_ExistingPartySheet> {
  final _searchCtrl = TextEditingController();
  late List<Contact> _filtered = widget.contacts;

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts.where((c) => c.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: widget.partyType == ContactType.customer
                      ? AppLocalizations.of(context).searchCustomerHint
                      : AppLocalizations.of(context).searchSupplierHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _filter,
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(widget.partyType == ContactType.customer
                          ? AppLocalizations.of(context).noCustomersYet
                          : AppLocalizations.of(context).noSuppliersYet))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.phone ?? ''),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
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
    );
  }
}
