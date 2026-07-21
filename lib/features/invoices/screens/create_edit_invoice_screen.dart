import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../scan/services/ocr_service.dart';
import '../services/invoice_repository.dart';
import '../services/tax_rule_config_repository.dart';
import 'invoice_preview_share_screen.dart';

class CreateEditInvoiceScreen extends StatefulWidget {
  final Book book;
  const CreateEditInvoiceScreen({super.key, required this.book});

  @override
  State<CreateEditInvoiceScreen> createState() => _CreateEditInvoiceScreenState();
}

class _LineItemDraft {
  final String id = const Uuid().v4();
  final descCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final rateCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  double taxRate;

  _LineItemDraft({this.taxRate = 0});

  InvoiceLineItem toModel() => InvoiceLineItem(
        id: id,
        description: descCtrl.text.trim(),
        hsnSac: hsnCtrl.text.trim().isEmpty ? null : hsnCtrl.text.trim(),
        qty: double.tryParse(qtyCtrl.text) ?? 1,
        rateePaise: Money.rupeesStringToPaise(rateCtrl.text),
        discountPaise: Money.rupeesStringToPaise(discountCtrl.text),
        taxRatePercent: taxRate,
      );

  bool get isValid =>
      descCtrl.text.trim().isNotEmpty && (double.tryParse(rateCtrl.text) ?? 0) > 0;
}

const kIndianStates = [
  'Andhra Pradesh', 'Bihar', 'Delhi', 'Gujarat', 'Karnataka', 'Kerala',
  'Madhya Pradesh', 'Maharashtra', 'Punjab', 'Rajasthan', 'Tamil Nadu',
  'Telangana', 'Uttar Pradesh', 'West Bengal',
];

class _CreateEditInvoiceScreenState extends State<CreateEditInvoiceScreen> {
  final _contactRepo = ContactRepository();
  final _invoiceRepo = InvoiceRepository();
  final _taxConfigRepo = TaxRuleConfigRepository();

  DateTime _invoiceDate = DateTime.now();
  Contact? _selectedCustomer;
  String? _newCustomerState;
  final List<_LineItemDraft> _lineItems = [_LineItemDraft()];
  List<double> _taxRates = _defaultRatesFallback;
  bool _saving = false;

  static const _defaultRatesFallback = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _loadTaxRates();
  }

  Future<void> _loadTaxRates() async {
    final rates = await _taxConfigRepo.ratesForDate(_invoiceDate);
    if (mounted) setState(() => _taxRates = rates);
  }

  int get _grandTotalPaise =>
      _lineItems.map((li) => li.isValid ? li.toModel().totalAmountPaise : 0).fold(0, (a, b) => a + b);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
      _loadTaxRates();
    }
  }

  Future<void> _pickOrAddCustomer() async {
    final result = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPickerSheet(bookId: widget.book.id, contactRepo: _contactRepo),
    );
    if (result != null) {
      setState(() {
        _selectedCustomer = result;
        _newCustomerState ??= widget.book.state;
      });
    }
  }

  Future<void> _scanOldInvoice() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xfile == null) return;

    final ocrService = OcrService();
    final result = await ocrService.scanReceipt(File(xfile.path));
    ocrService.dispose();
    if (!mounted) return;

    if (!result.success || result.rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't read the scan — please add line items manually.")),
      );
      return;
    }

    // Best-effort heuristic only (SRS 4.5's "from a scan" is explicitly a
    // convenience - the user always reviews/corrects before finalizing).
    final amountPattern = RegExp(r'(\d[\d,]*\.?\d{0,2})\s*$');
    final candidateLines = result.rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 3 && amountPattern.hasMatch(l))
        .take(10)
        .toList();

    setState(() {
      _lineItems.clear();
      for (final line in candidateLines) {
        final match = amountPattern.firstMatch(line);
        final amountStr = match?.group(1)?.replaceAll(',', '') ?? '0';
        final desc = line.substring(0, match?.start ?? line.length).trim();
        final draft = _LineItemDraft(taxRate: _taxRates.isNotEmpty ? _taxRates.first : 0);
        draft.descCtrl.text = desc.isEmpty ? 'Item' : desc;
        draft.rateCtrl.text = amountStr;
        _lineItems.add(draft);
      }
      if (_lineItems.isEmpty) _lineItems.add(_LineItemDraft());
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prefilled from scan — please review before saving.')),
    );
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a customer.')),
      );
      return;
    }
    if (_newCustomerState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the customer\'s state.')),
      );
      return;
    }
    final validItems = _lineItems.where((li) => li.isValid).map((li) => li.toModel()).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item with a description and rate.')),
      );
      return;
    }

    setState(() => _saving = true);
    final invoice = await _invoiceRepo.createInvoice(
      book: widget.book,
      invoiceDate: _invoiceDate,
      customerContactId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      customerState: _newCustomerState ?? widget.book.state ?? '',
      customerGstin: _selectedCustomer!.gstin,
      lineItems: validItems,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewShareScreen(invoice: invoice, book: widget.book),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan an old invoice/quotation',
            onPressed: _scanOldInvoice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invoice Date'),
            subtitle: Text('${_invoiceDate.day}/${_invoiceDate.month}/${_invoiceDate.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_selectedCustomer?.name ?? 'Select Customer'),
            subtitle: _selectedCustomer?.gstin != null ? Text('GSTIN: ${_selectedCustomer!.gstin}') : null,
            trailing: const Icon(Icons.person_search),
            onTap: _pickOrAddCustomer,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _newCustomerState,
            decoration: const InputDecoration(
              labelText: 'Customer State * (determines CGST+SGST vs IGST)',
            ),
            items: kIndianStates
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _newCustomerState = v),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Line Items', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Line'),
                onPressed: () => setState(() =>
                    _lineItems.add(_LineItemDraft(taxRate: _taxRates.isNotEmpty ? _taxRates.first : 0))),
              ),
            ],
          ),
          for (int i = 0; i < _lineItems.length; i++)
            _buildLineItemCard(i, _lineItems[i]),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Grand Total: ${Money.format(_grandTotalPaise)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save & Preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(int index, _LineItemDraft item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_lineItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _lineItems.removeAt(index)),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: item.hsnCtrl,
                    decoration: const InputDecoration(labelText: 'HSN/SAC'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate (₹)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount (₹)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: _taxRates.contains(item.taxRate) ? item.taxRate : null,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    items: _taxRates
                        .map((r) => DropdownMenuItem(value: r, child: Text('$r%')))
                        .toList(),
                    onChanged: (v) => setState(() => item.taxRate = v ?? 0),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                item.isValid ? 'Line total: ${Money.format(item.toModel().totalAmountPaise)}' : '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final String bookId;
  final ContactRepository contactRepo;
  const _CustomerPickerSheet({required this.bookId, required this.contactRepo});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  bool _addingNew = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: _addingNew ? _buildAddForm() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New'),
                onPressed: () => setState(() => _addingNew = true),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Contact>>(
              stream: widget.contactRepo.watchContacts(widget.bookId, type: ContactType.customer),
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? [];
                if (contacts.isEmpty) {
                  return const Center(child: Text('No customers yet. Tap "New" to add one.'));
                }
                return ListView(
                  children: contacts
                      .map((c) => ListTile(
                            title: Text(c.name),
                            subtitle: Text(c.gstin ?? c.phone ?? ''),
                            onTap: () => Navigator.pop(context, c),
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('New Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
        TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
        TextField(controller: _gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN (optional)')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final contact = await widget.contactRepo.createContact(
              bookId: widget.bookId,
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
              type: ContactType.customer,
            );
            if (mounted) Navigator.pop(context, contact);
          },
          child: const Text('Add & Select'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
