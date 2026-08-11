import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../design/app_colors.dart';
import '../design/app_motion.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import 'money_text.dart';

/// The canonical metric tile.
///
/// Replaces four near-identical private implementations that had drifted
/// apart (`_StatCard`, `_NumberCard`, and two `_buildSummaryCard`s) - each
/// with its own padding, radius, font sizes and color logic. One component
/// means the dashboard, bills and khata summaries are now provably
/// identical, and a density change is a one-line edit.
///
/// Supports hover/press states because this app also ships on Windows
/// desktop, where a non-reactive clickable surface feels broken.
class AppStatCard extends StatefulWidget {
  final String label;

  /// Optional second line under the label, e.g. "To Collect".
  final String? sublabel;

  /// Amount in paise. Mutually exclusive with [valueText].
  final int? amountPaise;

  /// Pre-formatted value, for non-money metrics (counts, percentages).
  final String? valueText;

  /// Small helper line under the value, e.g. "3 sales bill(s) pending".
  final String? caption;

  final AppTone tone;
  final IconData? icon;
  final MoneySign sign;
  final VoidCallback? onTap;

  /// Renders a skeleton instead of the value. Prevents the layout shift
  /// you get from swapping a spinner for content.
  final bool loading;

  const AppStatCard({
    super.key,
    required this.label,
    this.sublabel,
    this.amountPaise,
    this.valueText,
    this.caption,
    this.tone = AppTone.neutral,
    this.icon,
    this.sign = MoneySign.magnitude,
    this.onTap,
    this.loading = false,
  }) : assert(amountPaise != null || valueText != null || loading,
            'AppStatCard needs an amountPaise, a valueText, or loading:true');

  @override
  State<AppStatCard> createState() => _AppStatCardState();
}

class _AppStatCardState extends State<AppStatCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final tone = tones.byTone(widget.tone);
    final interactive = widget.onTap != null;

    final labelText = _NoWordBreakLabel(
      text: widget.label,
      style: theme.textTheme.labelMedium?.copyWith(color: tone.fg),
    );
    final iconBadge = widget.icon == null
        ? null
        : Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: tone.fg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(widget.icon, size: 14, color: tone.fg),
          );

    // Icon and label always share one row, on phone and desktop alike -
    // even a phone-width card three-to-a-row is safe, since
    // [_NoWordBreakLabel] shrinks a label that doesn't fit instead of ever
    // hard-wrapping a word mid-way.
    final header = iconBadge == null
        ? labelText
        : Row(
            children: [
              iconBadge,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: labelText),
            ],
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (widget.sublabel != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            widget.sublabel!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone.fg.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // FittedBox so a long amount (or a large OS font scale) shrinks
        // instead of clipping - amounts must stay fully readable.
        SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: widget.loading
                ? _Skeleton(color: tone.fg.withValues(alpha: 0.15))
                : widget.amountPaise != null
                    ? MoneyText(
                        widget.amountPaise!,
                        tone: widget.tone,
                        sign: widget.sign,
                        style: theme.textTheme.headlineSmall,
                      )
                    : Text(
                        widget.valueText!,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: tone.fg, fontWeight: FontWeight.w700)
                            .tabular,
                      ),
          ),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.caption!,
            style: theme.textTheme.labelSmall?.copyWith(color: tones.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: interactive ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          // Press reads as a subtle "push in" rather than a bounce.
          transform: _pressed
              ? (Matrix4.identity()..scaleByDouble(0.985, 0.985, 1, 1))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: _hovered
                ? Color.alphaBlend(tone.fg.withValues(alpha: 0.04), tone.bg)
                : tone.bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _hovered ? tone.fg.withValues(alpha: 0.35) : tone.border,
              width: AppBorders.hairline,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// The full-width, sideways counterpart to [AppStatCard]: a tinted icon
/// badge, label + optional detail line, and the amount - the same anatomy
/// [TransactionTile] uses for the register list.
///
/// This is what a phone-width row of metrics becomes. Two or three
/// [AppStatCard]s squeezed side by side at ~360dp read as barely-legible
/// slivers, so each metric takes a full row instead, where the label has
/// room to stay unbroken and the amount keeps its size. Wide viewports keep
/// the compact N-across [AppStatCard] row, which has the space for it.
///
/// Lives here next to [AppStatCard] rather than inside one dashboard widget
/// because the dashboard's summary, outstanding and due/overdue rows all
/// collapse the same way - the same reason [AppStatCard] itself is shared.
class AppStatRow extends StatelessWidget {
  final String label;

  /// Optional second line under the label, e.g. "To Collect · 3 bill(s)".
  /// Compose it from the same keys the wide layout passes as
  /// `sublabel`/`caption` rather than translating a combined string.
  final String? detail;

  final int amountPaise;
  final MoneySign sign;
  final AppTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  const AppStatRow({
    super.key,
    required this.label,
    this.detail,
    required this.amountPaise,
    this.sign = MoneySign.magnitude,
    required this.tone,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final toneColors = tones.byTone(tone);
    final interactive = onTap != null;

    return Material(
      color: toneColors.bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: toneColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneColors.fg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: toneColors.fg),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(color: toneColors.fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: MoneyText(
                    amountPaise,
                    tone: tone,
                    sign: sign,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              if (interactive) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(Icons.chevron_right, size: 18, color: tones.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A label that word-wraps across up to 2 lines like plain [Text], but
/// falls back to auto-shrinking (never splitting a single word across
/// lines) when even one word in it is wider than the space available.
///
/// This is what a bare [Text] with `maxLines: 2` can't do: given no space
/// to break at, the text engine hard-wraps mid-word to stay within the
/// line - which is exactly what turned short single-word labels like
/// "Income"/"Expense" into "Incom" / "e" on phone-width cards narrow
/// enough that even the icon-stacking above (see [_AppStatCardState])
/// isn't quite enough room. Measuring the widest word and switching
/// strategy only when normal wrapping would be forced to split it means
/// legitimately multi-word labels ("Pending to Collect") still get the
/// nicer 2-line wrap at full size whenever that fits.
///
/// Wraps a real [Text] child (rather than painting text itself) so
/// `find.text(...)` and screen-reader semantics keep working exactly as
/// they do for every other label in the app - the tests across this
/// codebase rely on that. A [RenderProxyBox] rather than a [LayoutBuilder]:
/// every row of these cards on the dashboard/bills/khata screens sits
/// inside an [IntrinsicHeight] (see e.g. `summary_numbers_row.dart`) so the
/// row resolves an equal, finite height before laying out its children -
/// [LayoutBuilder] cannot answer the intrinsic-dimension queries that
/// requires ("LayoutBuilder does not support returning intrinsic
/// dimensions"), so it would crash every card row in the app.
/// [RenderProxyBox] forwards intrinsics/semantics/hit-testing to the real
/// child for free; only layout and paint need customizing here, the same
/// way [RenderFittedBox] scales a child without being one itself.
class _NoWordBreakLabel extends SingleChildRenderObjectWidget {
  final String text;
  final TextStyle? style;

  _NoWordBreakLabel({required this.text, required this.style})
      : super(child: Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis));

  @override
  _RenderNoWordBreakLabel createRenderObject(BuildContext context) {
    return _RenderNoWordBreakLabel(
      text: text,
      style: style,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderNoWordBreakLabel renderObject) {
    renderObject
      ..text = text
      ..style = style
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

class _RenderNoWordBreakLabel extends RenderProxyBox {
  _RenderNoWordBreakLabel({
    required String text,
    required TextStyle? style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  })  : _text = text,
        _style = style,
        _textDirection = textDirection,
        _textScaler = textScaler;

  String _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
    markNeedsLayout();
  }

  TextStyle? _style;
  set style(TextStyle? value) {
    if (_style == value) return;
    _style = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    markNeedsLayout();
  }

  // 1 outside the shrink case, so paint/hitTestChildren stay plain passthrough.
  double _scale = 1;

  // The condition that matters is purely "does the widest single word fit
  // in the available width" - NOT whether the wrapped text overflows 2
  // lines. A word forced to hard-break can still fit exactly within 2
  // lines (e.g. "Incom" / "e"), so checking for wrap overflow alone would
  // miss it; checking the widest word directly catches it either way.
  double _widestWord() {
    var widest = 0.0;
    for (final word in _text.split(' ')) {
      if (word.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: word, style: _style),
        textDirection: _textDirection,
        textScaler: _textScaler,
        maxLines: 1,
      )..layout();
      if (tp.width > widest) widest = tp.width;
    }
    return widest;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    final maxWidth = constraints.maxWidth;
    final needsShrink = maxWidth.isFinite && _widestWord() > maxWidth;

    if (needsShrink) {
      // Lay the real Text out unconstrained to get its natural one-line
      // size (a single word with no space to wrap at renders as one line
      // regardless of the child's own maxLines), then scale that down to
      // fit - the same trick RenderFittedBox uses.
      child.layout(const BoxConstraints(), parentUsesSize: true);
      final natural = child.size;
      _scale = natural.width <= 0 ? 1 : (maxWidth / natural.width).clamp(0.0, 1.0);
      size = constraints.constrain(Size(maxWidth, natural.height * _scale));
    } else {
      _scale = 1;
      child.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);
      size = constraints.constrain(child.size);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_scale == 1) {
      context.paintChild(child, offset);
      return;
    }
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(child, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    if (_scale == 1) return child.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }
}

/// Loading placeholder sized to match the value line, so content swapping
/// in causes zero layout shift.
class _Skeleton extends StatelessWidget {
  final Color color;
  const _Skeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}
