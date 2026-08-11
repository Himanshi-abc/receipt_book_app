import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/book_model.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../invoices/services/invoice_repository.dart';
import '../../invoices/services/tax_rule_config_repository.dart';
import '../../khata/widgets/party_picker_field.dart';
import '../../products/screens/add_product_screen.dart';
import '../../products/services/product_repository.dart';
import 'product_line_item_screen.dart';

/// Stored values, not display copy. The selected mode is persisted on the
/// Invoice and printed on the PDF, so these strings must stay stable and
/// language-independent; [paymentModeLabel] translates them for display.
const kPaymentModes = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque', 'Other'];

/// The translated caption for one of [kPaymentModes]. Falls back to the
/// stored value so an older invoice carrying a mode no longer in the list
/// still renders something rather than blank.
String paymentModeLabel(AppLocalizations l10n, String mode) => switch (mode) {
      'Cash' => l10n.paymentModeCash,
      'UPI' => l10n.paymentModeUpi,
      'Card' => l10n.paymentModeCard,
      'Bank Transfer' => l10n.paymentModeBankTransfer,
      'Cheque' => l10n.paymentModeCheque,
      'Other' => l10n.paymentModeOther,
      _ => mode,
    };

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

  /// Defaults to bill date + [Invoice.defaultCreditDays], and keeps
  /// tracking the bill date until the user picks a due date themselves -
  /// after that it's theirs and moving the bill date won't overwrite it.
  DateTime _dueDate = DateTime.now().add(const Duration(days: Invoice.defaultCreditDays));
  bool _dueDatePickedManually = false;

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
  String _partyLabelOf(AppLocalizations l10n) =>
      _isSales ? l10n.partyCustomer : l10n.partySupplier;

  /// paise -> editable string, but blank (not "0") when there's nothing to
  /// show yet - matches the rest of the form's blank-by-default fields.
  String _editableOrBlank(int paise) => paise == 0 ? '' : Money.paiseToEditableString(paise);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInvoice;
    if (existing != null) {
      _billDate = existing.invoiceDate;
      // effectiveDueDate, not dueDate: a bill saved before due dates
      // existed should open showing the same +7 default it would get now,
      // and treating it as "already chosen" keeps that shown value stable.
      _dueDate = existing.effectiveDueDate;
      _dueDatePickedManually = true;
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
      setState(() {
        _billDate = picked;
        // A due date the user never touched keeps following the bill date.
        // One they did pick is only nudged if the new bill date would leave
        // it in the past, which can't be what they meant.
        if (!_dueDatePickedManually || _dueDate.isBefore(picked)) {
          _dueDate = picked.add(const Duration(days: Invoice.defaultCreditDays));
        }
      });
      _loadTaxRates();
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_billDate) ? _billDate : _dueDate,
      firstDate: _billDate, // a bill can't fall due before it was raised
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDatePickedManually = true;
      });
    }
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
    if (picked == null || !mounted) return;

    // Picking a product no longer drops it straight onto the bill at its
    // catalogue price: the agreed price and quantity are settled first, on
    // a screen where the with-tax and without-tax figures are both
    // editable. See ProductLineItemScreen.
    final line = await Navigator.push<InvoiceLineItem>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductLineItemScreen(product: picked),
      ),
    );
    if (line == null) return;

    setState(() => _lineItems.add(_BillLineItemDraft.fromLineItem(line)));
  }

  void _removeLineItem(_BillLineItemDraft draft) {
    setState(() => _lineItems.remove(draft));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            _isSales ? l10n.selectACustomerFirst : l10n.selectASupplierFirst),
      ));
      return;
    }
    final validItems = _lineItems.where((li) => li.isValid).map((li) => li.toModel()).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addAtLeastOneProduct)));
      return;
    }

    setState(() => _saving = true);
    final existing = widget.existingInvoice;
    final invoice = existing == null
        ? await InvoiceRepository().createInvoice(
            book: widget.book,
            invoiceDate: _billDate,
            dueDate: _dueDate,
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
            dueDate: _dueDate,
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
          content: Text(existing == null
              ? l10n.invoiceCreated(invoice.invoiceNumber)
              : l10n.invoiceUpdated(invoice.invoiceNumber)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final partyLabel = _partyLabelOf(l10n);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (_isSales ? l10n.editSale : l10n.editPurchase)
            : (_isSales ? l10n.newSale : l10n.newPurchase)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: l10n.date,
                  date: _billDate,
                  icon: Icons.calendar_today,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: l10n.dueDate,
                  date: _dueDate,
                  icon: Icons.event_outlined,
                  helperText: _dueDatePickedManually
                      ? null
                      : l10n.defaultCreditDays(Invoice.defaultCreditDays),
                  onTap: _pickDueDate,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(partyLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          PartyPickerField(
            bookId: widget.book.id,
            type: _partyType,
            label: partyLabel,
            selected: _selectedParty,
            onChanged: (c) => setState(() => _selectedParty = c),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.navProducts, style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addProduct),
                onPressed: _addProduct,
              ),
            ],
          ),
          for (final draft in _lineItems) _buildLineItemCard(draft),
          if (_lineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.noProductsAddedYet,
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          const Divider(height: 32),
          TextField(
            controller: _chargeDescCtrl,
            decoration:
                InputDecoration(labelText: l10n.additionalChargeDescription),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chargeAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.additionalChargeAmount),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _discountIsPercent
                        ? l10n.discountPercentOptional
                        : l10n.discountRupeesOptional,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<bool>(
                  initialValue: _discountIsPercent,
                  decoration: InputDecoration(labelText: l10n.fieldType),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('₹')),
                    DropdownMenuItem(value: true, child: Text('%')),
                  ],
                  onChanged: (v) => setState(() => _discountIsPercent = v ?? false),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: Text(l10n.grandTotalWithAmount(Money.format(_grandTotalPaise)),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountReceivedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Label only - the field, its controller and everything saved
            // through it stay "amountReceived" throughout, on a Purchase
            // bill exactly as on a Sale. Money paid to a supplier isn't
            // "received" from the business's point of view, so the UI text
            // says so; the underlying model doesn't need a second concept
            // for what is still the same field on the Invoice.
            decoration: InputDecoration(
              labelText: _isSales ? l10n.amountReceivedLabel : l10n.amountPaidLabel,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: InputDecoration(labelText: l10n.paymentMode),
            items: kPaymentModes
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(paymentModeLabel(l10n, m)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _paymentMode = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _fullyPaid,
            title: Text(l10n.markAsFullyPaid),
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
                : Text(_isEditing ? l10n.actionSave : l10n.actionCreate),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(_BillLineItemDraft draft) {
    final l10n = AppLocalizations.of(context);
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
                    decoration: InputDecoration(labelText: l10n.fieldDescription),
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
                    decoration: InputDecoration(labelText: l10n.priceLabel),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.qtyLabel),
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
                    decoration: InputDecoration(labelText: l10n.taxPercentLabel),
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

/// A read-only, tap-to-pick date input. Uses InputDecorator so it carries
/// the same border, label and helper-text treatment as the TextFields it
/// sits beside - a ListTile next to a TextField reads as two different
/// kinds of control.
class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final IconData icon;
  final String? helperText;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          // A blank (not null) helper reserves the line, so the two fields
          // stay the same height when only one of them has helper text.
          helperText: helperText ?? ' ',
          helperMaxLines: 1,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(icon, size: 18),
        ),
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}',
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
    final l10n = AppLocalizations.of(context);
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
                      decoration: InputDecoration(
                        hintText: l10n.searchProductsHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _filter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: l10n.addProduct,
                    onPressed: _createNew,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(l10n.noProductsFound))
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
