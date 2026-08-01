import 'package:flutter/material.dart';

/// Type scale.
///
/// Deliberately uses the platform UI font (SF on iOS, Roboto on Android)
/// rather than pulling a webfont: it costs zero bytes, renders instantly
/// offline, and matches OS conventions - all of which matter more here than
/// a bespoke typeface. What makes it feel designed is the *metrics*: a
/// restrained 6-step scale, tuned line heights, and negative tracking on
/// large text so headings read tight instead of airy.
class AppTypography {
  AppTypography._();

  /// Money and any figure that appears in a column.
  ///
  /// Proportional digits make "₹1,111" visibly narrower than "₹9,999",
  /// so a column of amounts wobbles. Tabular figures lock every digit to
  /// the same advance width - the single highest-impact detail in a
  /// financial UI, and the reason amounts now line up down every list.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const _display = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const _headline = TextStyle(
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const _titleLg = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const _titleMd = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const _titleSm = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const _bodyLg = TextStyle(fontSize: 16, height: 1.5);
  static const _bodyMd = TextStyle(fontSize: 14, height: 1.45);
  static const _bodySm = TextStyle(fontSize: 13, height: 1.4);

  static const _labelLg = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const _labelMd = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Captions / helper text. 11px is the floor - never go smaller.
  static const _labelSm = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: _display.copyWith(color: primary),
      headlineMedium: _headline.copyWith(color: primary),
      headlineSmall: _titleLg.copyWith(color: primary),
      titleLarge: _titleLg.copyWith(color: primary),
      titleMedium: _titleMd.copyWith(color: primary),
      titleSmall: _titleSm.copyWith(color: primary),
      bodyLarge: _bodyLg.copyWith(color: primary),
      bodyMedium: _bodyMd.copyWith(color: primary),
      bodySmall: _bodySm.copyWith(color: secondary),
      labelLarge: _labelLg.copyWith(color: primary),
      labelMedium: _labelMd.copyWith(color: secondary),
      labelSmall: _labelSm.copyWith(color: secondary),
    );
  }
}

/// `Theme.of(context).textTheme.titleMedium.tabular` for any numeric text.
extension TabularFiguresX on TextStyle {
  TextStyle get tabular => copyWith(fontFeatures: AppTypography.tabular);
}
