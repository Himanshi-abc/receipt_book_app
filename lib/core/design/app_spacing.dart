/// Spacing, radius and sizing tokens.
///
/// Everything is derived from a 4px base with an 8px rhythm: the even steps
/// (8/16/24/32...) carry layout, the odd half-steps (4/12/20) handle
/// intra-component gaps. Never hardcode an EdgeInsets value in a screen -
/// reach for a token so density can be retuned in one place.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Horizontal page gutter. Screens should use this rather than picking
  /// their own 12/16/left-right padding, so every screen's content sits on
  /// the same vertical rails.
  static const double pageGutter = lg;
}

class AppRadius {
  AppRadius._();

  /// Chips, badges, small inputs.
  static const double sm = 8;

  /// Default for inputs, buttons and dense cards.
  static const double md = 12;

  /// Cards and sheets - the app's signature corner.
  static const double lg = 16;

  /// Large surfaces (bottom sheets, dialogs, hero cards).
  static const double xl = 20;

  /// Pills / fully rounded.
  static const double full = 999;
}

/// Border widths. Enterprise surfaces lean on 1px hairlines rather than
/// heavy shadows - shadow is reserved for genuinely floating elements.
class AppBorders {
  AppBorders._();

  static const double hairline = 1;
  static const double emphasis = 1.5;
  static const double focus = 2;
}
