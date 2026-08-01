import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../utils/money.dart';

/// How the sign of an amount is rendered.
enum MoneySign {
  /// Always show the magnitude only. Use when an adjacent label already
  /// says the direction ("You'll pay ₹500") - a minus sign there would be
  /// a double negative and actively confusing.
  magnitude,

  /// Show a leading "-" only for negatives. Use for net figures where the
  /// sign *is* the information (Net Profit vs Net Loss, cashflow).
  auto,
}

/// The single way money is rendered anywhere in the app.
///
/// Centralising this fixes three things that were previously decided
/// ad-hoc at ~20 call sites: tabular figures (so columns of amounts align),
/// the green/red semantics of direction, and whether a negative shows as
/// "-₹500" or "₹500" next to a "You'll pay" label.
class MoneyText extends StatelessWidget {
  final int paise;

  /// Explicit tone. When null the tone is derived from the sign, which is
  /// the right default for net/derived figures.
  final AppTone? tone;

  final MoneySign sign;
  final TextStyle? style;

  /// Renders in [AppSemanticColors.textPrimary] instead of a tone color.
  /// For amounts where color would be noise (a bill's grand total in a
  /// list, where every row would otherwise be green).
  final bool muted;

  const MoneyText(
    this.paise, {
    super.key,
    this.tone,
    this.sign = MoneySign.magnitude,
    this.style,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    final resolvedTone = tone ?? (paise < 0 ? AppTone.negative : AppTone.positive);
    final color = muted ? tones.textPrimary : tones.byTone(resolvedTone).fg;

    final text = switch (sign) {
      MoneySign.magnitude => Money.format(paise.abs()),
      MoneySign.auto =>
        paise < 0 ? '-${Money.format(paise.abs())}' : Money.format(paise),
    };

    final base = style ?? theme.textTheme.titleMedium!;
    // Deliberately does NOT pin textScaler: amounts must keep honouring the
    // OS font-size setting. Callers that are width-constrained wrap this in
    // a FittedBox so large accessibility text shrinks rather than clipping.
    return Text(
      text,
      style: base.copyWith(color: color, fontWeight: FontWeight.w700).tabular,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
