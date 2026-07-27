import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:uuid/uuid.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/tax_math.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../invoices/services/tax_rule_config_repository.dart';
import '../../khata/screens/add_party_screen.dart';
import '../../products/screens/add_product_screen.dart';
import '../../products/services/product_repository.dart';

const kPaymentModes = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque', 'Other'];

class _BillLineItemDraft {
  final String id;
  final String? productId;
  final descCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final rateCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  double taxRate;

  _BillLineItemDraft({String? id, this.productId, this.taxRate = 0}) : id = id ?? const Uuid().v4();

  /// Rebuilds a draft from a previously saved line item, for editing an
  /// existing bill - keeps the original id rather than minting a new one.
  factory _BillLineItemDraft.fromLineItem(InvoiceLineItem li) {
    final draft = _BillLineItemDraft(id: li.id, productId: li.productId, taxRate: li.taxRatePercent);
    draft.descCtrl.text = li.description;
    draft.hsnCtrl.text = li.hsnSac ?? '';
    draft.qtyCtrl.text = li.qty == li.qty.roundToDouble()
        ? li.qty.toStringAsFixed(0)
        : li.qty.toString();
    draft.rateCtrl.text = Money.paiseToEditableString(li.rateePaise);
    draft.discountCtrl.text = li.discountPaise == 0 ? '0' : Money.paiseToEditableString(li.discountPaise);
    return draft;
  }

  InvoiceLineItem toModel() => InvoiceLineItem(
        id: id,
        description: descCtrl.text.trim(),
        hsnSac: hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
        qty: double.tryParse(qtyCtrl.text) ?? 1,
        rateePaise: Money.rupeesStringToPaise(rateCtrl.text),
        discountPaise: Money.rupeesStringToPaise(discountCtrl.text),
        taxRatePercent: taxRate,
        productId: productId,
      );

  bool get isValid =>
      descCtrl.text.trim().isNotEmpty && (double.tryParse(rateCtrl.text) ?? 0) > 0;

  int get totalPaise => toModel().totalAmountPaise;
}

/// Replaces CreateEditInvoiceScreen: product-catalog-driven line items,
/// bill-level discount/charge, and payment capture at creation time. One
/// screen for both directions via [direction].
class CreateBillScreen extends StatefulWidget {
  final Book book;
  final BillDirection direction;

  /// Pre-selects this party (e.g. arriving from their khata ledger screen).
  final Contact? initialParty;

  /// When set, the form opens pre-filled with this bill's data and saving
  /// updates it in place instead of creating a new one.
  final Invoice? existingInvoice;

  const CreateBillScreen({
    super.key,
    required this.book,
    required this.direction,
    this.initialParty,
    this.existingInvoice,
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  Contact? _selectedParty;
  DateTime _billDate = DateTime.now();
  final List<_BillLineItemDraft> _lineItems = [];

  final _discountCtrl = TextEditingController();
  bool _discountIsPercent = false;
  final _chargeDescCtrl = TextEditingController();
  final _chargeAmountCtrl = TextEditingController();
  final _amountReceivedCtrl = TextEditingController();
  String? _paymentMode;
  bool _fullyPaid = false;

  List<double> _taxRates = const [0, 5, 12, 18, 28];
  bool _saving = false;

  bool get _isEditing => widget.existingInvoice != null;
  bool get _isSales => widget.direction == BillDirection.sales;
  ContactType get _partyType => _isSales ? ContactType.customer : ContactType.vendor;
  String get _partyLabel => _isSales ? 'Customer' : 'Supplier';

  /// paise -> editable string, but blank (not "0") when there's nothing to
  /// show yet - matches the rest of the form's blank-by-default fields.
  String _editableOrBlank(int paise) => paise == 0 ? '' : Money.paiseToEditableString(paise);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInvoice;
    if (existing != null) {
      _billDate = existing.invoiceDate;
      _lineItems.addAll(existing.lineItems.map(_BillLineItemDraft.fromLineItem));
      _discountCtrl.text = _editableOrBlank(existing.discountPaise);
      _chargeDescCtrl.text = existing.additionalChargeDescription ?? '';
      _chargeAmountCtrl.text = _editableOrBlank(existing.additionalChargePaise);
      _amountReceivedCtrl.text = _editableOrBlank(existing.amountReceivedPaise);
      _paymentMode = existing.paymentMode;
      _loadExistingParty(existing.customerContactId);
    } else {
      _selectedParty = widget.initialParty;
    }
    _loadTaxRates();
  }

  Future<void> _loadExistingParty(String contactId) async {
    final contacts = await ContactRepository().loadContacts(widget.book.id, type: _partyType);
    if (!mounted) return;
    setState(() {
      _selectedParty = contacts.where((c) => c.id == contactId).firstOrNull;
    });
  }

  Future<void> _loadTaxRates() async {
    final rates = await TaxRuleConfigRepository().ratesForDate(_billDate);
    if (mounted) setState(() => _taxRates = rates);
  }

  int get _lineItemsTotalPaise =>
      _lineItems.where((li) => li.isValid).fold(0, (a, li) => a + li.totalPaise);
  int get _discountPaise {
    if (!_discountIsPercent) return Money.rupeesStringToPaise(_discountCtrl.text);
    final percent = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    return (_lineItemsTotalPaise * percent / 100).round();
  }

  int get _chargePaise => Money.rupeesStringToPaise(_chargeAmountCtrl.text);
  int get _grandTotalPaise => _lineItemsTotalPaise - _discountPaise + _chargePaise;

  bool get _canSave =>
      _selectedParty != null && _lineItems.any((li) => li.isValid) && !_saving;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _billDate = picked);
      _loadTaxRates();
    }
  }

  Future<void> _selectExistingParty() async {
    final bookId = widget.book.id;
    final contacts = await ContactRepository().loadContacts(bookId, type: _partyType);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExistingPartySheet(contacts: contacts, partyLabel: _partyLabel),
    );
    if (picked != null) setState(() => _selectedParty = picked);
  }

  Future<void> _addPartyManually() async {
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(builder: (_) => AddPartyScreen(defaultType: _partyType)),
    );
    if (result != null) setState(() => _selectedParty = result);
  }

  Future<void> _importFromContacts() async {
    final granted = await fc.FlutterContacts.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts access was denied.')),
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

    final saved = await ContactRepository().saveContact(
      bookId: widget.book.id,
      name: picked.displayName,
      phone: picked.phones.isNotEmpty ? picked.phones.first.number : null,
      type: _partyType,
    );
    setState(() => _selectedParty = saved);
  }

  Future<void> _addProduct() async {
    final bookId = widget.book.id;
    final products = await ProductRepository().loadProducts(bookId);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(bookId: bookId, initialProducts: products),
    );
    if (picked == null) return;

    final draft = _BillLineItemDraft(productId: picked.id, taxRate: picked.taxRatePercent);
    draft.descCtrl.text = picked.name;
    draft.hsnCtrl.text = picked.hsnCode ?? '';
    final exclusivePaise = picked.priceIncludesTax
        ? exclusiveFromInclusive(picked.sellingPricePaise, picked.taxRatePercent)
        : picked.sellingPricePaise;
    draft.rateCtrl.text = Money.paiseToEditableString(exclusivePaise);
    setState(() => _lineItems.add(draft));
  }

  void _removeLineItem(_BillLineItemDraft draft) {
    setState(() => _lineItems.remove(draft));
  }

  Future<void> _save() async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Select a $_partyLabel first.')));
      return;
    }
    final validItems = _lineItems.where((li) => li.isValid).map((li) => li.toModel()).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one product.')));
      return;
    }

    setState(() => _saving = true);
    final existing = widget.existingInvoice;
    final invoice = existing == null
        ? await InvoiceRepository().createInvoice(
            book: widget.book,
            invoiceDate: _billDate,
            customerContactId: _selectedParty!.id,
            customerName: _selectedParty!.name,
            customerState: widget.book.state ?? '',
            customerGstin: _selectedParty!.gstin,
            lineItems: validItems,
            billDirection: widget.direction,
            discountPaise: _discountPaise,
            additionalChargeDescription:
                _chargeDescCtrl.text.trim().isEmpty ? null : _chargeDescCtrl.text.trim(),
            additionalChargePaise: _chargePaise,
            amountReceivedPaise: Money.rupeesStringToPaise(_amountReceivedCtrl.text),
            paymentMode: _paymentMode,
          )
        : await InvoiceRepository().updateInvoice(
            existing: existing,
            invoiceDate: _billDate,
            customerContactId: _selectedParty!.id,
            customerName: _selectedParty!.name,
            customerState: widget.book.state ?? '',
            customerGstin: _selectedParty!.gstin,
            lineItems: validItems,
            discountPaise: _discountPaise,
            additionalChargeDescription:
                _chargeDescCtrl.text.trim().isEmpty ? null : _chargeDescCtrl.text.trim(),
            additionalChargePaise: _chargePaise,
            amountReceivedPaise: Money.rupeesStringToPaise(_amountReceivedCtrl.text),
            paymentMode: _paymentMode,
          );

    // Just create/save and go back - no auto-opened preview. The user can
    // see the full invoice any time from its transaction entry (Bills list
    // or the linked Customers/Suppliers khata entry - see
    // PartyDetailScreen._showEntryActions' "View Invoice").
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${existing == null ? 'Created' : 'Updated'} ${invoice.invoiceNumber}.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (_isSales ? 'Edit Sale' : 'Edit Purchase')
            : (_isSales ? 'New Sale' : 'New Purchase')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text('${_billDate.day}/${_billDate.month}/${_billDate.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const Divider(),
          Text(_partyLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_selectedParty != null)
            Card(
              child: ListTile(
                title: Text(_selectedParty!.name),
                subtitle: Text(_selectedParty!.phone ?? ''),
                trailing: TextButton(onPressed: _selectExistingParty, child: const Text('Change')),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: Text('Select $_partyLabel'),
                  onPressed: _selectExistingParty,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text('Add $_partyLabel'),
                  onPressed: _addPartyManually,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Import from Contacts'),
                  onPressed: _importFromContacts,
                ),
              ],
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Products', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                onPressed: _addProduct,
              ),
            ],
          ),
          for (final draft in _lineItems) _buildLineItemCard(draft),
          if (_lineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No products added yet.', style: TextStyle(color: Colors.grey.shade600)),
            ),
          const Divider(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _discountIsPercent ? 'Discount (%, optional)' : 'Discount (₹, optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<bool>(
                  initialValue: _discountIsPercent,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('₹')),
                    DropdownMenuItem(value: true, child: Text('%')),
                  ],
                  onChanged: (v) => setState(() => _discountIsPercent = v ?? false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chargeDescCtrl,
            decoration: const InputDecoration(labelText: 'Additional Charge description (optional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chargeAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Additional Charge amount (₹, optional)'),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Grand Total: ${Money.format(_grandTotalPaise)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountReceivedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount Received (₹)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: const InputDecoration(labelText: 'Payment Mode'),
            items: kPaymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _paymentMode = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _fullyPaid,
            title: const Text('Mark as fully paid'),
            onChanged: (v) => setState(() {
              _fullyPaid = v ?? false;
              if (_fullyPaid) {
                _amountReceivedCtrl.text = Money.paiseToEditableString(_grandTotalPaise);
              }
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(_BillLineItemDraft draft) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeLineItem(draft),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: _taxRates.contains(draft.taxRate) ? draft.taxRate : null,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    items: _taxRates
                        .map((r) => DropdownMenuItem(value: r, child: Text('$r%')))
                        .toList(),
                    onChanged: (v) => setState(() => draft.taxRate = v ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Text(Money.format(draft.totalPaise), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingPartySheet extends StatefulWidget {
  final List<Contact> contacts;
  final String partyLabel;
  const _ExistingPartySheet({required this.contacts, required this.partyLabel});

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
                  hintText: 'Search ${widget.partyLabel.toLowerCase()}s',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _filter,
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text('No ${widget.partyLabel.toLowerCase()}s yet.'))
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

class _ProductPickerSheet extends StatefulWidget {
  final String bookId;
  final List<Product> initialProducts;
  const _ProductPickerSheet({required this.bookId, required this.initialProducts});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<Product> _all = widget.initialProducts;
  late List<Product> _filtered = widget.initialProducts;

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  (p.productCode?.toString().contains(q) ?? false))
              .toList();
    });
  }

  Future<void> _createNew() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    // Reload so the newly created product shows up to pick.
    final refreshed = await ProductRepository().loadProducts(widget.bookId);
    if (mounted) {
      setState(() {
        _all = refreshed;
        _filter(_searchCtrl.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search products by name or code',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _filter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Product',
                    onPressed: _createNew,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = _filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              p.productCode?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(p.name),
                          subtitle: Text(Money.format(p.sellingPricePaise)),
                          onTap: () => Navigator.pop(context, p),
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

/// Duplicated from AddPartyScreen's private device-contact picker rather
/// than shared, to keep this screen's changes self-contained.
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
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
