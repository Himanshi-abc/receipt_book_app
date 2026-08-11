import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/tax_math.dart';
import '../../../l10n/app_localizations.dart';

/// Sits between picking a product and adding it to a bill.
///
/// Products carry one price, stored either tax-inclusive or tax-exclusive
/// (Product.priceIncludesTax) - but which basis a user thinks in is a
/// property of the conversation they just had with the customer, not of the
/// catalogue. Someone who agreed "1180 all-in" should be able to type 1180;
/// someone quoting ex-tax should be able to type 1000. So both price fields
/// are live and each rewrites the other through the tax rate.
///
/// The exclusive figure is the one that gets stored, because that is what
/// InvoiceLineItem.rateePaise means and what the GST breakdown on the
/// invoice is computed from.
///
/// The tax rate itself is NOT editable here - it's fixed to whatever the
/// product was saved with in the catalogue (Products > Add/Edit). Which
/// rate applies is a one-time decision about the product, not a per-sale
/// one; re-asking it on every bill would just be an extra tap that changes
/// nothing anyone actually wants to change at this point. Only the two
/// prices and the quantity are editable.
class ProductLineItemScreen extends StatefulWidget {
  final Product product;

  const ProductLineItemScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductLineItemScreen> createState() => _ProductLineItemScreenState();
}

class _ProductLineItemScreenState extends State<ProductLineItemScreen> {
  final _exclusiveCtrl = TextEditingController();
  final _inclusiveCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  /// Fixed for the life of this screen - tax rate is a property of the
  /// product, set once when it's added or edited in the catalogue, not a
  /// per-bill decision. Re-deciding it here, per sale, is exactly the extra
  /// step this screen exists to remove.
  late final double _taxRate;

  /// Exclusive price is the source of truth; the inclusive field is a view
  /// onto it. Kept as an int of paise rather than re-parsing the field, so
  /// rounding happens once.
  int _exclusivePaise = 0;

  /// Guards the two price fields from rewriting each other in a loop.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _taxRate = product.taxRatePercent;

    // The catalogue price is only the starting point - whichever basis it
    // was stored in, both fields open populated and either can be changed.
    _exclusivePaise = product.priceIncludesTax
        ? exclusiveFromInclusive(product.sellingPricePaise, _taxRate)
        : product.sellingPricePaise;

    _qtyCtrl.text = _formatQty(1);
    _writePriceFields();

    _exclusiveCtrl.addListener(_onExclusiveChanged);
    _inclusiveCtrl.addListener(_onInclusiveChanged);
    _qtyCtrl.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _exclusiveCtrl.dispose();
    _inclusiveCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  static String _formatQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();

  double get _qty {
    final parsed = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return parsed <= 0 ? 0 : parsed;
  }

  int get _inclusiveUnitPaise => inclusiveFromExclusive(_exclusivePaise, _taxRate);

  /// The canonical line maths - built through InvoiceLineItem rather than
  /// recomputed here, so this preview can never disagree with the invoice.
  InvoiceLineItem _buildLine() => InvoiceLineItem(
        id: const Uuid().v4(),
        description: widget.product.name,
        hsnSac: widget.product.hsnCode?.trim().isEmpty ?? true
            ? null
            : widget.product.hsnCode,
        qty: _qty,
        rateePaise: _exclusivePaise,
        taxRatePercent: _taxRate,
        productId: widget.product.id,
      );

  /// Rewrites both price fields from [_exclusivePaise]. Called once, on
  /// load - the tax rate that also feeds this can no longer change, so
  /// unlike an earlier version of this screen there's no second trigger.
  void _writePriceFields() {
    _syncing = true;
    _exclusiveCtrl.text = Money.paiseToEditableString(_exclusivePaise);
    _inclusiveCtrl.text = Money.paiseToEditableString(_inclusiveUnitPaise);
    _syncing = false;
  }

  void _onExclusiveChanged() {
    if (_syncing) return;
    _exclusivePaise = Money.rupeesStringToPaise(_exclusiveCtrl.text);
    _syncing = true;
    _inclusiveCtrl.text = Money.paiseToEditableString(_inclusiveUnitPaise);
    _syncing = false;
    setState(() {});
  }

  void _onInclusiveChanged() {
    if (_syncing) return;
    final typedInclusive = Money.rupeesStringToPaise(_inclusiveCtrl.text);
    _exclusivePaise = exclusiveFromInclusive(typedInclusive, _taxRate);
    _syncing = true;
    _exclusiveCtrl.text = Money.paiseToEditableString(_exclusivePaise);
    // Deliberately not rewriting the inclusive field the user is typing in:
    // round-tripping 100 through an 18% rate lands back on 100, but not for
    // every value, and having the cursor jump under your fingers is worse
    // than a one-paisa display difference.
    _syncing = false;
    setState(() {});
  }

  void _onQtyChanged() => setState(() {});

  void _bumpQty(double delta) {
    final next = (_qty + delta).clamp(1, 999999).toDouble();
    _qtyCtrl.text = _formatQty(next);
  }

  bool get _canSave => _qty > 0 && _exclusivePaise > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final line = _buildLine();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addItem)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            children: [
              _productHeader(theme, tones),
              const SizedBox(height: AppSpacing.xl),

              Text(l10n.pricePerUnit, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _taxRate == 0
                    ? l10n.itemNotTaxedHint
                    : l10n.editEitherPriceHint,
                style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _exclusiveCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.priceWithoutTax,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _inclusiveCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.priceWithTax,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.receipt_outlined),
                  helperText: _taxRate == 0
                      ? null
                      : l10n.includesTaxAmount(
                          _trimRate(_taxRate),
                          Money.format(_inclusiveUnitPaise - _exclusivePaise),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(l10n.quantity, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _quantityRow(),
              const SizedBox(height: AppSpacing.xl),

              _totalCard(theme, tones, line),
              const SizedBox(height: AppSpacing.xl),

              FilledButton(
                onPressed: _canSave ? () => Navigator.pop(context, line) : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(l10n.addToBill),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drops the trailing ".0" that every whole rate would otherwise carry.
  static String _trimRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

  Widget _productHeader(ThemeData theme, AppSemanticColors tones) {
    final product = widget.product;
    final l10n = AppLocalizations.of(context);
    final details = [
      if (product.productCode != null) l10n.codeWithValue('${product.productCode}'),
      if (product.hsnCode != null && product.hsnCode!.trim().isNotEmpty)
        l10n.hsnWithValue(product.hsnCode!),
      if (product.unit != null && product.unit!.trim().isNotEmpty) product.unit!,
      // Shown, not chosen: the rate is fixed to whatever this product was
      // saved with (Products > Edit), so it's stated here as a fact about
      // the item rather than offered as another decision on this screen.
      _taxRate == 0 ? l10n.noTax : l10n.taxRatePercent(_trimRate(_taxRate)),
    ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tones.byTone(AppTone.brand).bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tones.byTone(AppTone.brand).border),
          ),
          child: Icon(
            product.type == ProductItemType.service
                ? Icons.handyman_outlined
                : Icons.inventory_2_outlined,
            color: tones.byTone(AppTone.brand).fg,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: theme.textTheme.titleMedium),
              if (details.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _quantityRow() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton.outlined(
          onPressed: _qty > 1 ? () => _bumpQty(-1) : null,
          icon: const Icon(Icons.remove),
          tooltip: l10n.decrease,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: _qtyCtrl,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixText: widget.product.unit?.trim().isEmpty ?? true
                  ? null
                  : widget.product.unit,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton.outlined(
          onPressed: () => _bumpQty(1),
          icon: const Icon(Icons.add),
          tooltip: l10n.increase,
        ),
      ],
    );
  }

  Widget _totalCard(ThemeData theme, AppSemanticColors tones, InvoiceLineItem line) {
    final l10n = AppLocalizations.of(context);
    final brand = tones.byTone(AppTone.brand);

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: strong
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodySmall?.copyWith(color: tones.textSecondary),
              ),
              Text(
                value,
                style: strong
                    ? theme.textTheme.titleMedium?.copyWith(color: brand.fg)
                    : theme.textTheme.bodySmall?.copyWith(color: tones.textSecondary),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: brand.bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: brand.border),
      ),
      child: Column(
        children: [
          row(l10n.taxableValue, Money.format(line.taxableAmountPaise)),
          if (_taxRate > 0)
            row(l10n.taxWithRate(_trimRate(_taxRate)),
                Money.format(line.taxAmountPaise)),
          const Divider(height: AppSpacing.lg),
          row(l10n.itemTotal, Money.format(line.totalAmountPaise), strong: true),
        ],
      ),
    );
  }
}
