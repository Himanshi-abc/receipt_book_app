import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/product_category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/tax_rule_config_model.dart';
import '../../../core/services/product_category_repository.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/tax_math.dart';
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
  static final ProductCategory _createCategorySentinel =
      ProductCategory(id: '__create_new__', bookId: '', name: '+ Create new category');

  bool get _isEditing => widget.existingProduct != null;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      Money.rupeesStringToPaise(_sellingPriceCtrl.text) > 0 &&
      _taxRate != null;

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
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create category'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(nameCtrl.text.trim()),
            child: const Text('Create'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmAndDelete() async {
    final existing = widget.existingProduct;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_type == ProductItemType.product ? 'Product' : 'Service'}'),
        content: Text('Delete "${existing.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ProductRepository().softDelete(existing);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${existing.name} deleted.')));
      Navigator.of(context).pop();
    }
  }

  Widget? _buildTaxHelperText() {
    final entered = Money.rupeesStringToPaise(_sellingPriceCtrl.text);
    if (entered <= 0 || _taxRate == null) return null;
    final text = _priceIncludesTax
        ? '≈ ${Money.format(exclusiveFromInclusive(entered, _taxRate!))} excl. tax'
        : '≈ ${Money.format(inclusiveFromExclusive(entered, _taxRate!))} incl. tax';
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (_type == ProductItemType.product ? 'Edit Product' : 'Edit Service')
            : 'Add Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
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
                'Product Code: ${widget.existingProduct!.productCode}',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
          SegmentedButton<ProductItemType>(
            segments: const [
              ButtonSegment(value: ProductItemType.product, label: Text('Product')),
              ButtonSegment(value: ProductItemType.service, label: Text('Service')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: _type == ProductItemType.product ? 'Product Name *' : 'Service Name *',
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
                  decoration: const InputDecoration(labelText: 'Selling Price (₹) *'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<bool>(
                  initialValue: _priceIncludesTax,
                  decoration: const InputDecoration(labelText: 'Price'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Without Tax')),
                    DropdownMenuItem(value: true, child: Text('With Tax')),
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
            decoration: const InputDecoration(labelText: 'Tax Rate *'),
            items: _taxRates.map((r) => DropdownMenuItem(value: r, child: Text('$r%'))).toList(),
            onChanged: (v) => setState(() => _taxRate = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purchasePriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Purchase Price (₹, optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hsnCtrl,
            decoration: const InputDecoration(
              labelText: 'HSN Code (optional)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitCtrl,
            decoration: const InputDecoration(labelText: 'Unit (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductCategory>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            items: [
              ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
              DropdownMenuItem(
                value: _createCategorySentinel,
                child: Text(_createCategorySentinel.name),
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
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
