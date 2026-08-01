import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_motion.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/invoice_template.dart';
import '../../books/providers/book_provider.dart';
import 'invoice_template_preview_screen.dart';

/// Widest a single template card is allowed to get.
///
/// Sized so two rows of five fit the ~600dp of body height a 1366x768
/// Windows window leaves after its title bar, the AppBar and the helper
/// line - i.e. so every template is on screen at once on a laptop. On a
/// phone the natural 2-column width is already below this, so the cap never
/// bites there and cards still fill the screen.
@visibleForTesting
const double kInvoiceTemplateMaxTileWidth = 180;

/// Columns the template grid uses at a given available width.
///
/// Driven by width, not by platform: a Windows window dragged narrow, an
/// Android tablet held in portrait and a split-screen phone all deserve the
/// layout that fits, and a `Platform.isX` check gets all three wrong. The
/// intended phone/tablet/desktop counts fall out of these naturally (phone
/// ~400dp -> 2, tablet portrait ~800dp -> 3, laptop 1366dp+ -> 5), with a
/// 4-column step so the jump from tablet to laptop isn't abrupt.
int invoiceTemplateGridColumns(double width) {
  if (width >= 1280) return 5;
  if (width >= 1000) return 4;
  if (width >= 680) return 3;
  return 2;
}

/// Height of one card at [tileWidth], for the layout maths and its test.
@visibleForTesting
double invoiceTemplateTileHeight(double tileWidth) =>
    tileWidth * _TemplateCard.previewRatio + _TemplateCard.captionHeight;

/// Business Book only: pick which of the 10 InvoiceTemplateStyle presets
/// this book's invoices render with (InvoicePdfService reads
/// Book.invoiceTemplateId). Tapping a card opens a full sample invoice
/// (real PDF render, dummy data) via InvoiceTemplatePreviewScreen; "Use
/// This Template" there is what actually applies it, so every invoice
/// this book generates from then on shares the same look.
class InvoiceTemplateScreen extends StatefulWidget {
  const InvoiceTemplateScreen({super.key});

  @override
  State<InvoiceTemplateScreen> createState() => _InvoiceTemplateScreenState();
}

class _InvoiceTemplateScreenState extends State<InvoiceTemplateScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    final book = context.read<BookProvider>().currentBook;
    _selectedId = invoiceTemplateById(book?.invoiceTemplateId).id;
  }

  Future<void> _openPreview(InvoiceTemplateStyle style) async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceTemplatePreviewScreen(style: style)),
    );
    if (applied == true && mounted) {
      setState(() => _selectedId = style.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${style.name}" is now this book\'s invoice template.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Template')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.md,
              AppSpacing.pageGutter,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a template to see a full sample invoice, then apply it. '
                'It\'s used everywhere this book generates a bill.',
                style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
              ),
            ),
          ),
          Expanded(
            child: InvoiceTemplateGrid(
              selectedId: _selectedId,
              onSelect: _openPreview,
            ),
          ),
        ],
      ),
    );
  }
}

/// The responsive card grid, split out from the screen so it can be laid
/// out in a test - the screen itself needs a BookProvider, which builds a
/// Firestore client the moment it is constructed.
class InvoiceTemplateGrid extends StatelessWidget {
  final String selectedId;
  final void Function(InvoiceTemplateStyle style) onSelect;

  const InvoiceTemplateGrid({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = invoiceTemplateGridColumns(constraints.maxWidth);
        const gutter = AppSpacing.pageGutter;
        final spacing = columns >= 4 ? AppSpacing.md : AppSpacing.lg;

        // The tile height is derived rather than guessed at: a fixed
        // childAspectRatio that looks right at 2 columns clips the caption
        // at 5, because the tile narrows but the text doesn't. Measuring
        // the preview against its own width and adding a constant caption
        // block keeps every breakpoint correct by construction.
        //
        // The width cap is what keeps all 10 templates reachable: letting
        // tiles grow to fill a 1366dp laptop made each card ~390dp tall,
        // which pushed the entire second row of five below the fold - the
        // screen then looks like it only has five templates. Capped, both
        // rows fit on a laptop at once and the cards read as thumbnails to
        // compare rather than as posters.
        final fullTileWidth =
            (constraints.maxWidth - gutter * 2 - spacing * (columns - 1)) / columns;
        final tileWidth = math.min(fullTileWidth, kInvoiceTemplateMaxTileWidth);
        final tileHeight = invoiceTemplateTileHeight(tileWidth);

        // Once capped, the grid is narrower than the screen - centre it
        // rather than leaving all the slack on the right.
        final gridWidth = tileWidth * columns + spacing * (columns - 1) + gutter * 2;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                gutter,
                AppSpacing.sm,
                gutter,
                AppSpacing.xxl,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: tileWidth / tileHeight,
              ),
              itemCount: kInvoiceTemplates.length,
              itemBuilder: (ctx, i) {
                final style = kInvoiceTemplates[i];
                return _TemplateCard(
                  style: style,
                  selected: style.id == selectedId,
                  onTap: () => onSelect(style),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final InvoiceTemplateStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({required this.style, required this.selected, required this.onTap});

  /// Preview height as a multiple of the card's width. Short of A4's 1.414
  /// so that two rows of thumbnails fit a laptop screen at once - it still
  /// reads unmistakably as portrait paper, which is all a thumbnail has to
  /// do. The real page proportions are on the preview screen behind a tap.
  static const double previewRatio = 1.24;

  /// Fixed height of the name + description block. Constant across
  /// breakpoints because the text doesn't shrink with the card, which is
  /// exactly why a single childAspectRatio can't serve every column count.
  ///
  /// Sized against the real type scale rather than eyeballed: name
  /// (14 x 1.3 = 18.2) + 2 gap + two description lines (11 x 1.3 x 2 =
  /// 28.6) + 16 padding = 64.8, rounded up for headroom. Trim this and the
  /// description clips.
  static const double captionHeight = 66;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final primary = theme.colorScheme.primary;
    final selected = widget.selected;

    return MouseRegion(
      // The Windows build is a first-class target here, and an unreactive
      // clickable surface reads as broken with a pointer.
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            color: tones.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? primary
                  : _hovered
                      ? tones.borderStrong
                      : tones.border,
              width: selected ? AppBorders.focus : AppBorders.hairline,
            ),
            boxShadow: selected || _hovered
                ? [
                    BoxShadow(
                      color: (selected ? primary : Colors.black)
                          .withValues(alpha: selected ? 0.22 : 0.10),
                      blurRadius: selected ? 10 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MockInvoicePreview(style: widget.style),
                    if (selected)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          // A labelled pill, not a bare tick: "which one is
                          // this book using?" is the question this screen
                          // exists to answer, and a checkmark alone makes
                          // the user infer it.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 11, color: Colors.white),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'In use',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: _TemplateCard.captionHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.style.name,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          widget.style.description,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: tones.textTertiary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lightweight, fast Flutter-widget mock of the template's look - not a
/// real PDF render (that would need a full generate() round-trip per
/// card) but close enough to compare all 10 styles at a glance.
///
/// Laid out at a fixed design size and scaled to fit, so the mock's
/// proportions are identical whether it's in a 2-across phone grid or a
/// 5-across desktop one. Sizing its bars in raw pixels instead would make
/// them look chunky on a phone and hairline-thin on a laptop.
class _MockInvoicePreview extends StatelessWidget {
  final InvoiceTemplateStyle style;
  const _MockInvoicePreview({required this.style});

  static const double _designWidth = 180;
  static const double _designHeight = _designWidth * _TemplateCard.previewRatio;

  Color get _primary => Color(style.primaryColor);
  Color get _accent => Color(style.accentColor);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildTable(),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(width: 46, height: 7, color: _primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isBand = style.headerLayout == InvoiceHeaderLayout.colorBand;
    final titleColor = isBand ? (style.lightTextOnAccent ? Colors.white : Colors.black) : _primary;
    final lineColor =
        isBand ? (style.lightTextOnAccent ? Colors.white70 : Colors.black54) : Colors.grey.shade400;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 6, color: titleColor),
            const SizedBox(height: 4),
            Container(width: 28, height: 3, color: lineColor),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 26, height: 5, color: titleColor),
            const SizedBox(height: 4),
            Container(width: 20, height: 3, color: lineColor),
          ],
        ),
      ],
    );

    switch (style.headerLayout) {
      case InvoiceHeaderLayout.plain:
        return content;
      case InvoiceHeaderLayout.colorBand:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(3)),
          child: content,
        );
      case InvoiceHeaderLayout.sidebarAccent:
        // IntrinsicHeight is required, not decorative: this Row sits in a
        // Column, so its incoming maxHeight is unbounded, and `stretch`
        // alone hands the accent bar a tight *infinite* height - which
        // throws during layout and blanks the card. Resolving a finite
        // height first (the tallest child) is what actually makes the bar
        // run the full height of the header. Same trap as the dashboard
        // summary rows; see summary_numbers_row.dart.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: _primary),
              const SizedBox(width: 6),
              Expanded(child: content),
            ],
          ),
        );
    }
  }

  Widget _buildTable() {
    switch (style.tableStyle) {
      case InvoiceTableStyle.bordered:
        return Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400, width: 0.6)),
          child: Column(
            children: [
              Container(height: 10, color: _accent),
              for (var i = 0; i < 3; i++)
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                  ),
                ),
            ],
          ),
        );
      case InvoiceTableStyle.striped:
        return Column(
          children: [
            Container(height: 10, color: _primary),
            for (var i = 0; i < 3; i++) Container(height: 9, color: i.isOdd ? _accent : Colors.white),
          ],
        );
      case InvoiceTableStyle.minimalLines:
        return Column(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 1))),
            ),
            for (var i = 0; i < 3; i++)
              Container(
                height: 9,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
              ),
          ],
        );
    }
  }
}
