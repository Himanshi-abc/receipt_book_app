import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/product_category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/tax_rule_config_model.dart';
import '../../../core/services/product_category_repository.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/tax_math.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/providers/book_provider.dart';
import '../../invoices/services/tax_rule_config_repository.dart';
import '../services/product_repository.dart';

/// Add a new Product/Service, or edit an existing one when [existingProduct]
/// is set (Save then updates it in place - ProductRepository.saveProduct
/// already accepts an id for upsert).
class AddProductScreen extends StatefulWidget {
  final Product? existingProduct;
  const AddProductScreen({this.existingProduct, super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _hsnCtrl;
  late final TextEditingController _unitCtrl;
  late ProductItemType _type;
  late bool _priceIncludesTax;
  double? _taxRate;
  ProductCategory? _selectedCategory;

  List<double> _taxRates = TaxRuleConfig.defaultRates();
  final _categoryRepo = ProductCategoryRepository();
  List<ProductCategory> _categories = [];
  bool _saving = false;

  /// Sentinel dropdown item; selecting it opens the "new category" dialog
  /// instead of actually being assignable as a category.
  /// Only [ProductCategory.id] identifies this row; `name` is replaced with
  /// the translated caption at render time, so the placeholder here is
  /// never what the user sees.
  static final ProductCategory _createCategorySentinel =
      ProductCategory(id: '__create_new__', bookId: '', name: '+ Create new category');

  bool get _isEditing => widget.existingProduct != null;

  /// A tax rate is only mandatory once the price is entered "With Tax":
  /// an inclusive price is meaningless without knowing the rate baked into
  /// it (there's no way to derive the taxable base from it), whereas a
  /// "Without Tax" price stands on its own and simply means 0% until a
  /// rate is picked. Default is Without Tax, so most products save with
  /// just a name and a price.
  bool get _taxRateRequired => _priceIncludesTax;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      Money.rupeesStringToPaise(_sellingPriceCtrl.text) > 0 &&
      (!_taxRateRequired || _taxRate != null);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProduct;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _sellingPriceCtrl = TextEditingController(
      text: existing != null ? Money.paiseToEditableString(existing.sellingPricePaise) : '',
    );
    _purchasePriceCtrl = TextEditingController(
      text: existing?.purchasePricePaise != null
          ? Money.paiseToEditableString(existing!.purchasePricePaise!)
          : '',
    );
    _hsnCtrl = TextEditingController(text: existing?.hsnCode ?? '');
    _unitCtrl = TextEditingController(text: existing?.unit ?? '');
    _type = existing?.type ?? ProductItemType.product;
    _priceIncludesTax = existing?.priceIncludesTax ?? false;
    _taxRate = existing?.taxRatePercent;
    _loadTaxRates();
    _loadCategories();
  }

  Future<void> _loadTaxRates() async {
    final rates = await TaxRuleConfigRepository().ratesForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _taxRates = rates;
      if (_taxRate != null && !_taxRates.contains(_taxRate)) {
        _taxRates = [..._taxRates, _taxRate!]..sort();
      }
    });
  }

  Future<void> _loadCategories() async {
    final bookId = context.read<BookProvider>().currentBook?.id;
    if (bookId == null) return;
    var categories = await _categoryRepo.loadCategories(bookId);

    // A product saved before this list existed may carry a free-text
    // category name that isn't a persisted ProductCategory yet - persist
    // it now so it becomes a normal, reusable entry going forward.
    final existingName = widget.existingProduct?.category?.trim();
    if (existingName != null &&
        existingName.isNotEmpty &&
        !categories.any((c) => c.name == existingName)) {
      final created = await _categoryRepo.createCategory(bookId: bookId, name: existingName);
      categories = [...categories, created];
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (existingName != null && existingName.isNotEmpty) {
        _selectedCategory = categories.where((c) => c.name == existingName).firstOrNull;
      }
    });
  }

  Future<void> _promptCreateCategory() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.createCategory),
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
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final bookId = context.read<BookProvider>().currentBook?.id;
    if (bookId == null) return;
    final category = await _categoryRepo.createCategory(bookId: bookId, name: name);
    if (!mounted) return;
    setState(() {
      _categories = [..._categories, category];
      _selectedCategory = category;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.currentBook!;

    await ProductRepository().saveProduct(
      id: widget.existingProduct?.id,
      createdAt: widget.existingProduct?.createdAt,
      bookId: book.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      sellingPricePaise: Money.rupeesStringToPaise(_sellingPriceCtrl.text),
      priceIncludesTax: _priceIncludesTax,
      taxRatePercent: _taxRate ?? 0,
      purchasePricePaise: _purchasePriceCtrl.text.trim().isEmpty
          ? null
          : Money.rupeesStringToPaise(_purchasePriceCtrl.text),
      hsnCode: _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim(),
      unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
      category: _selectedCategory?.name,
      productCode: widget.existingProduct?.productCode,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).savedSnack)),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmAndDelete() async {
    final existing = widget.existingProduct;
    if (existing == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_type == ProductItemType.product
            ? l10n.deleteProductTitle
            : l10n.deleteServiceTitle),
        content: Text(l10n.deleteNamedItemConfirm(existing.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ProductRepository().softDelete(existing);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.itemDeleted(existing.name))));
      Navigator.of(context).pop();
    }
  }

  Widget? _buildTaxHelperText() {
    final entered = Money.rupeesStringToPaise(_sellingPriceCtrl.text);
    if (entered <= 0 || _taxRate == null) return null;
    final l10n = AppLocalizations.of(context);
    final text = _priceIncludesTax
        ? l10n.approxExcludingTax(
            Money.format(exclusiveFromInclusive(entered, _taxRate!)))
        : l10n.approxIncludingTax(
            Money.format(inclusiveFromExclusive(entered, _taxRate!)));
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (_type == ProductItemType.product ? l10n.editProduct : l10n.editService)
            : l10n.addProduct),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.actionDelete,
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.existingProduct?.productCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.productCodeWithValue('${widget.existingProduct!.productCode}'),
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
          SegmentedButton<ProductItemType>(
            segments: [
              ButtonSegment(
                  value: ProductItemType.product, label: Text(l10n.typeProduct)),
              ButtonSegment(
                  value: ProductItemType.service, label: Text(l10n.typeService)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: _type == ProductItemType.product
                  ? l10n.productNameRequired
                  : l10n.serviceNameRequired,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _sellingPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: l10n.sellingPriceRequired),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<bool>(
                  initialValue: _priceIncludesTax,
                  decoration: InputDecoration(labelText: l10n.priceShort),
                  items: [
                    DropdownMenuItem(value: false, child: Text(l10n.withoutTax)),
                    DropdownMenuItem(value: true, child: Text(l10n.withTax)),
                  ],
                  onChanged: (v) => setState(() => _priceIncludesTax = v ?? false),
                ),
              ),
            ],
          ),
          if (_buildTaxHelperText() case final helper?) helper,
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            initialValue: _taxRates.contains(_taxRate) ? _taxRate : null,
            decoration: InputDecoration(
              labelText:
                  _taxRateRequired ? l10n.taxRateRequired : l10n.taxRateOptional,
              helperText: _taxRateRequired
                  ? l10n.taxRateRequiredHelper
                  : l10n.taxRateOptionalHelper,
            ),
            items: _taxRates.map((r) => DropdownMenuItem(value: r, child: Text('$r%'))).toList(),
            onChanged: (v) => setState(() => _taxRate = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purchasePriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                InputDecoration(labelText: l10n.purchasePriceOptional),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hsnCtrl,
            decoration: InputDecoration(
              labelText: l10n.hsnCodeOptional,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitCtrl,
            decoration: InputDecoration(labelText: l10n.unitOptional),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductCategory>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(labelText: l10n.categoryOptional),
            items: [
              ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
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
              setState(() => _selectedCategory = v);
            },
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
