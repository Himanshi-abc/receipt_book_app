import 'package:flutter/material.dart';

/// Raw palette. These are the only literal colors in the app - nothing else
/// should ever write `Color(0x...)` or reach for `Colors.green.shade700`.
/// Screens consume the *semantic* layer below (AppSemanticColors), never
/// these constants directly, so re-theming is a one-file change.
class AppPalette {
  AppPalette._();

  // ---------------------------------------------------------------------
  // Brand - a deepened, desaturated teal. Keeps the product's existing
  // identity but drops the stock `Colors.teal` look that reads as
  // "default Material app" rather than a considered financial product.
  // ---------------------------------------------------------------------
  static const brand50 = Color(0xFFF0FDFA);
  static const brand100 = Color(0xFFCCFBF1);
  static const brand200 = Color(0xFF99F6E4);
  static const brand300 = Color(0xFF5EEAD4);
  static const brand400 = Color(0xFF2DD4BF);
  static const brand500 = Color(0xFF14B8A6);
  static const brand600 = Color(0xFF0D9488);
  static const brand700 = Color(0xFF0F766E);
  static const brand800 = Color(0xFF115E59);
  static const brand900 = Color(0xFF134E4A);

  // ---------------------------------------------------------------------
  // Neutrals - a cool slate ramp. Cool grays sit better against the teal
  // brand than pure/warm grays and keep long numeric tables calm.
  // ---------------------------------------------------------------------
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral800 = Color(0xFF1E293B);
  static const neutral900 = Color(0xFF0F172A);
  static const neutral950 = Color(0xFF020617);

  // ---------------------------------------------------------------------
  // Money semantics. In a ledger these are not decoration - they are the
  // primary signal, so they get their own deliberate ramps rather than
  // borrowing Material's error/tertiary slots.
  // ---------------------------------------------------------------------

  /// Money in / you'll receive / profit.
  static const positive50 = Color(0xFFECFDF5);
  static const positive100 = Color(0xFFD1FAE5);
  static const positive300 = Color(0xFF6EE7B7);
  static const positive400 = Color(0xFF34D399);
  static const positive600 = Color(0xFF059669);
  static const positive700 = Color(0xFF047857);
  static const positive900 = Color(0xFF064E3B);

  /// Money out / you'll pay / loss.
  static const negative50 = Color(0xFFFEF2F2);
  static const negative100 = Color(0xFFFEE2E2);
  static const negative300 = Color(0xFFFCA5A5);
  static const negative400 = Color(0xFFF87171);
  static const negative600 = Color(0xFFDC2626);
  static const negative700 = Color(0xFFB91C1C);
  static const negative900 = Color(0xFF7F1D1D);

  /// Pending / partially paid / needs attention.
  static const warning50 = Color(0xFFFFFBEB);
  static const warning100 = Color(0xFFFEF3C7);
  static const warning300 = Color(0xFFFCD34D);
  static const warning400 = Color(0xFFFBBF24);
  static const warning600 = Color(0xFFD97706);
  static const warning700 = Color(0xFFB45309);
  static const warning900 = Color(0xFF78350F);

  /// Informational / totals / neutral emphasis.
  static const info50 = Color(0xFFEFF6FF);
  static const info100 = Color(0xFFDBEAFE);
  static const info300 = Color(0xFF93C5FD);
  static const info400 = Color(0xFF60A5FA);
  static const info600 = Color(0xFF2563EB);
  static const info700 = Color(0xFF1D4ED8);
  static const info900 = Color(0xFF1E3A8A);
}

/// The tone a surface/metric carries. Screens express *meaning*
/// ("this number is money coming in") and the design system decides the
/// actual color, so light/dark and any future rebrand stay consistent.
enum AppTone { neutral, brand, positive, negative, warning, info }

/// A resolved tone: the colors needed to render a tinted container with an
/// accessible foreground on top of it.
@immutable
class ToneColors {
  /// Strong color - icons, value text, borders.
  final Color fg;

  /// Subtle tinted background.
  final Color bg;

  /// Hairline border for the tinted container.
  final Color border;

  const ToneColors({required this.fg, required this.bg, required this.border});

  static ToneColors lerp(ToneColors a, ToneColors b, double t) => ToneColors(
        fg: Color.lerp(a.fg, b.fg, t)!,
        bg: Color.lerp(a.bg, b.bg, t)!,
        border: Color.lerp(a.border, b.border, t)!,
      );
}

/// Semantic color tokens exposed through the theme.
///
/// Registered as a [ThemeExtension] so a widget reads
/// `context.tones.positive.fg` and automatically gets the correct value in
/// light or dark - rather than hardcoding `Colors.green.shade700`, which is
/// what made the previous UI impossible to theme.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final ToneColors neutral;
  final ToneColors brand;
  final ToneColors positive;
  final ToneColors negative;
  final ToneColors warning;
  final ToneColors info;

  /// Page background, one step behind [surface].
  final Color canvas;

  /// Default card/sheet background.
  final Color surface;

  /// Raised or selected rows.
  final Color surfaceElevated;

  /// Hairline dividers and card borders.
  final Color border;

  /// Stronger border for focus/selected outlines.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// Captions, helper text, disabled labels.
  final Color textTertiary;

  const AppSemanticColors({
    required this.neutral,
    required this.brand,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.info,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  /// Foreground/background pairs are chosen so body-size text on the tinted
  /// background clears WCAG AA (4.5:1): 600/700-weight ink on a 50-weight
  /// tint in light mode, 300/400-weight ink on a near-black tint in dark.
  static const light = AppSemanticColors(
    neutral: ToneColors(
      fg: AppPalette.neutral700,
      bg: AppPalette.neutral100,
      border: AppPalette.neutral200,
    ),
    brand: ToneColors(
      fg: AppPalette.brand700,
      bg: AppPalette.brand50,
      border: AppPalette.brand100,
    ),
    positive: ToneColors(
      fg: AppPalette.positive700,
      bg: AppPalette.positive50,
      border: AppPalette.positive100,
    ),
    negative: ToneColors(
      fg: AppPalette.negative700,
      bg: AppPalette.negative50,
      border: AppPalette.negative100,
    ),
    warning: ToneColors(
      fg: AppPalette.warning700,
      bg: AppPalette.warning50,
      border: AppPalette.warning100,
    ),
    info: ToneColors(
      fg: AppPalette.info700,
      bg: AppPalette.info50,
      border: AppPalette.info100,
    ),
    canvas: AppPalette.neutral50,
    surface: AppPalette.neutral0,
    surfaceElevated: AppPalette.neutral0,
    border: AppPalette.neutral200,
    borderStrong: AppPalette.neutral300,
    textPrimary: AppPalette.neutral900,
    textSecondary: AppPalette.neutral600,
    textTertiary: AppPalette.neutral500,
  );

  static const dark = AppSemanticColors(
    neutral: ToneColors(
      fg: AppPalette.neutral300,
      bg: AppPalette.neutral800,
      border: AppPalette.neutral700,
    ),
    brand: ToneColors(
      fg: AppPalette.brand300,
      bg: Color(0xFF0C2F2C),
      border: AppPalette.brand900,
    ),
    positive: ToneColors(
      fg: AppPalette.positive300,
      bg: Color(0xFF07281D),
      border: AppPalette.positive900,
    ),
    negative: ToneColors(
      fg: AppPalette.negative300,
      bg: Color(0xFF2C1113),
      border: AppPalette.negative900,
    ),
    warning: ToneColors(
      fg: AppPalette.warning300,
      bg: Color(0xFF2B1D06),
      border: AppPalette.warning900,
    ),
    info: ToneColors(
      fg: AppPalette.info300,
      bg: Color(0xFF10203F),
      border: AppPalette.info900,
    ),
    canvas: AppPalette.neutral950,
    surface: AppPalette.neutral900,
    surfaceElevated: AppPalette.neutral800,
    border: AppPalette.neutral800,
    borderStrong: AppPalette.neutral700,
    textPrimary: AppPalette.neutral50,
    textSecondary: AppPalette.neutral400,
    textTertiary: AppPalette.neutral500,
  );

  ToneColors byTone(AppTone tone) => switch (tone) {
        AppTone.neutral => neutral,
        AppTone.brand => brand,
        AppTone.positive => positive,
        AppTone.negative => negative,
        AppTone.warning => warning,
        AppTone.info => info,
      };

  @override
  AppSemanticColors copyWith({
    ToneColors? neutral,
    ToneColors? brand,
    ToneColors? positive,
    ToneColors? negative,
    ToneColors? warning,
    ToneColors? info,
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return AppSemanticColors(
      neutral: neutral ?? this.neutral,
      brand: brand ?? this.brand,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      neutral: ToneColors.lerp(neutral, other.neutral, t),
      brand: ToneColors.lerp(brand, other.brand, t),
      positive: ToneColors.lerp(positive, other.positive, t),
      negative: ToneColors.lerp(negative, other.negative, t),
      warning: ToneColors.lerp(warning, other.warning, t),
      info: ToneColors.lerp(info, other.info, t),
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

/// `context.tones.positive.fg` - the one-liner every widget uses.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get tones =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
