import 'package:flutter/material.dart';

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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.icon != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: tone.fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(widget.icon, size: 14, color: tone.fg),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(color: tone.fg),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
